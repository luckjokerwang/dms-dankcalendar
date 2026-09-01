import os
import sqlite3
import datetime
import re
from typing import Dict, Any, List, Optional
from .dcal_client import DcalClient
from .types import TasksListResult, TaskItem

from .tag_service import TagService
from .task_classifier import TaskClassifier

def get_local_tz_offset() -> str:
    """Returns local timezone offset string like '+08:00'."""
    now = datetime.datetime.now(datetime.timezone.utc).astimezone()
    offset = now.strftime("%z") # e.g. "+0800"
    if len(offset) == 5:
        return offset[:3] + ":" + offset[3:]
    return "+08:00"

def format_rfc3339(dt_str: str, is_task_due: bool = False) -> str:
    """Ensures datetime string is strictly valid RFC3339 with timezone offset."""
    if not dt_str:
        return ""
    dt_str = dt_str.strip()
    
    # If already has timezone (Z or +HH:MM or -HH:MM)
    if dt_str.endswith("Z") or re.search(r"[+-]\d{2}:\d{2}$", dt_str):
        return dt_str
    
    dt_str = dt_str.replace(" ", "T")
    if len(dt_str) == 10: # Date only (YYYY-MM-DD)
        if is_task_due:
            dt_str += "T23:59:59"
        else:
            dt_str += "T00:00:00"
    elif len(dt_str) == 16: # YYYY-MM-DDTHH:MM
        dt_str += ":00"
        
    return dt_str + get_local_tz_offset()

def _get_created_map() -> Dict[str, str]:
    db_path = os.path.expanduser("~/.local/share/dankcal/dankcal.db")
    if not os.path.exists(db_path):
        return {}
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        cursor = conn.cursor()
        cursor.execute("SELECT id, created FROM tasks")
        created_map = {row[0]: str(row[1]) for row in cursor.fetchall() if row[0] and row[1]}
        conn.close()
        return created_map
    except Exception:
        return {}

class TaskService:
    def __init__(self, dcal: Optional[DcalClient] = None):
        self.dcal = dcal or DcalClient()

    def get_tasks_summary(self) -> TasksListResult:
        cals = self.dcal.get_calendars()
        task_cals = [c for c in cals if c.get("holdsTasks")]
        default_cal_id = task_cals[0]["id"] if task_cals else (cals[0]["id"] if cals else "")

        pending_tasks = []
        completed_tasks = []
        tag_counts = {}

        created_map = _get_created_map()

        for cal in task_cals:
            tasks = self.dcal.get_tasks(cal["id"])
            for t in tasks:
                raw_summary = t.get("summary", "")
                clean_summary, tags = TagService.parse_tags_detail(raw_summary)
                created_val = t.get("created") or created_map.get(t.get("id"), "")

                task_obj: TaskItem = {
                    "id": t.get("id", ""),
                    "summary": raw_summary,
                    "cleanSummary": clean_summary,
                    "tags": tags,
                    "calendarId": t.get("calendarId", cal["id"]),
                    "calendarName": cal.get("name", "Tasks"),
                    "status": t.get("status", "needs_action"),
                    "percentComplete": t.get("percentComplete", 0),
                    "priority": t.get("priority", 0),
                    "due": t.get("due"),
                    "created": created_val
                }

                if task_obj["status"] == "completed" or task_obj["percentComplete"] == 100:
                    completed_tasks.append(task_obj)
                else:
                    pending_tasks.append(task_obj)
                    for tg in tags:
                        tag_name = tg["name"]
                        tag_counts[tag_name] = tag_counts.get(tag_name, 0) + 1

        active_tags = []
        t_map = TagService.get_tag_map()
        for name, count in tag_counts.items():
            if count > 0:
                color = t_map.get(name, {}).get("color") or TagService.get_color_for_name(name)
                icon = t_map.get(name, {}).get("icon") or "label"
                active_tags.append({
                    "name": name,
                    "count": count,
                    "color": color,
                    "icon": icon
                })
        active_tags.sort(key=lambda x: -x["count"])

        return {
            "pending": pending_tasks,
            "completed": completed_tasks,
            "pendingCount": len(pending_tasks),
            "completedCount": len(completed_tasks),
            "defaultCalendarId": default_cal_id,
            "taskCalendars": task_cals,
            "allTags": active_tags
        }

    def batch_create(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        cals = self.dcal.get_calendars()
        event_cals = [c for c in cals if c.get("holdsEvents", True) and not c.get("holdsTasks")]
        task_cals = [c for c in cals if c.get("holdsTasks")]
        default_event_cal_id = event_cals[0]["id"] if event_cals else (cals[0]["id"] if cals else "")
        default_task_cal_id = task_cals[0]["id"] if task_cals else (cals[0]["id"] if cals else "")

        # Name map
        name_to_cal_id = {}
        for c in cals:
            if c.get("name"):
                name_to_cal_id[c["name"].lower()] = c["id"]
            if c.get("id"):
                name_to_cal_id[c["id"].lower()] = c["id"]

        created_events = 0
        created_tasks = 0
        errors = []

        for ev in payload.get("events", []):
            summary = (ev.get("title") or ev.get("summary") or "").strip()
            start_raw = ev.get("start")
            end_raw = ev.get("end") or start_raw
            if not summary or not start_raw:
                continue

            start = format_rfc3339(str(start_raw), is_task_due=False)
            end = format_rfc3339(str(end_raw), is_task_due=False) if end_raw else ""
            if not end or end == start:
                try:
                    dt_start = datetime.datetime.fromisoformat(start)
                    dt_end = dt_start + datetime.timedelta(minutes=30)
                    end = dt_end.isoformat()
                except Exception:
                    end = start

            all_day = bool(ev.get("allDay", False))
            loc = ev.get("location", "")
            cal_spec = (ev.get("calendarId") or ev.get("calendarName") or "").strip().lower()
            cal_id = name_to_cal_id.get(cal_spec) or default_event_cal_id

            ok = self.dcal.create_event(cal_id, summary, start, end, all_day, loc)
            if ok:
                created_events += 1
            else:
                errors.append(f"Failed to create event: {summary}")

        for t in payload.get("tasks", []):
            summary = (t.get("summary") or t.get("title") or "").strip()
            if not summary:
                continue
            if not TagService.extract_tags(summary):
                c_res = TaskClassifier.classify_single(summary)
                if c_res and c_res.get("taggedSummary"):
                    summary = c_res["taggedSummary"]
            cal_spec = (t.get("calendarId") or t.get("calendarName") or "").strip().lower()
            cal_id = name_to_cal_id.get(cal_spec) or default_task_cal_id
            p = int(t.get("priority", 0))
            due_raw = t.get("due")
            due = format_rfc3339(str(due_raw), is_task_due=True) if due_raw else None
            ok = self.dcal.create_task(cal_id, summary, p, due)
            if ok:
                created_tasks += 1
            else:
                errors.append(f"Failed to create task: {summary}")

        return {
            "createdEvents": created_events,
            "createdTasks": created_tasks,
            "success": len(errors) == 0,
            "errors": errors
        }

    def classify_task(self, text: str, model_override: Optional[str] = None) -> Dict[str, Any]:
        return TaskClassifier.classify_single(text, model_override=model_override)

    def classify_unclassified_tasks(self, model_override: Optional[str] = None) -> Dict[str, Any]:
        summary = self.get_tasks_summary()
        pending = summary.get("pending", [])
        unclassified = [t for t in pending if not t.get("tags")]
        return TaskClassifier.classify_batch(unclassified, model_override=model_override)

    def apply_tags_updates(self, updates: List[Dict[str, str]]) -> Dict[str, Any]:
        success_count = 0
        fail_count = 0
        for item in updates:
            t_id = item.get("id")
            tagged_summary = item.get("taggedSummary")
            if not t_id or not tagged_summary:
                continue
            ok = self.dcal.update_task(t_id, summary=tagged_summary)
            if ok:
                success_count += 1
            else:
                fail_count += 1
        return {
            "successCount": success_count,
            "failCount": fail_count,
            "total": len(updates)
        }
