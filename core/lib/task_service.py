import os
import sqlite3
from typing import Dict, Any, List, Optional
from .dcal_client import DcalClient
from .types import TasksListResult, TaskItem

from .tag_service import TagService
from .task_classifier import TaskClassifier

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
        cal_map = {c["id"]: c.get("name") or c.get("accountName") or "Tasks" for c in task_cals}
        default_cal_id = task_cals[0]["id"] if task_cals else ""

        all_tasks = self.dcal.get_tasks()
        created_map = _get_created_map()
        tag_map = TagService.get_tag_map()
        pending: List[TaskItem] = []
        completed: List[TaskItem] = []

        for t in all_tasks:
            t["calendarName"] = cal_map.get(t.get("calendarId", ""), "Tasks")
            if t.get("id") and t.get("id") in created_map:
                t["created"] = created_map[t["id"]]
            raw_summary = t.get("summary") or ""
            clean_sum, tags = TagService.parse_tags_detail(raw_summary, tag_map=tag_map)
            t["cleanSummary"] = clean_sum
            t["tags"] = tags
            if t.get("status") == "completed" or bool(t.get("completed")):
                completed.append(t)  # type: ignore
            else:
                pending.append(t)  # type: ignore

        def task_sort_key(idx_and_task):
            idx, t = idx_and_task
            p = t.get("priority") or 0
            p_rank = p if (1 <= p <= 9) else 10
            due_raw = t.get("due") or ""
            has_due = 0 if due_raw else 1
            due_val = due_raw if due_raw else "9999-99-99T99:99:99Z"
            created = t.get("created") or t.get("createdAt") or t.get("dtstamp") or ""
            summary = (t.get("summary") or "").strip().lower()
            return (p_rank, has_due, due_val, created, idx, summary)

        indexed = list(enumerate(pending))
        indexed.sort(key=task_sort_key)
        sorted_pending = [t for _, t in indexed]

        # Compute active tags currently present in pending tasks with counts
        active_tags_map: Dict[str, Dict[str, Any]] = {}
        for t in sorted_pending:
            for tag_obj in t.get("tags", []):
                tname = tag_obj["name"]
                if tname not in active_tags_map:
                    active_tags_map[tname] = {
                        "name": tname,
                        "color": tag_obj["color"],
                        "icon": tag_obj.get("icon", "label"),
                        "count": 0
                    }
                active_tags_map[tname]["count"] += 1
        active_tags = list(active_tags_map.values())

        return {
            "pending": sorted_pending,
            "completed": completed,
            "pendingCount": len(sorted_pending),
            "completedCount": len(completed),
            "defaultCalendarId": default_cal_id,
            "taskCalendars": [{"id": c["id"], "name": c.get("name") or "Tasks"} for c in task_cals],
            "allTags": active_tags
        }

    def batch_create(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        cals = self.dcal.get_calendars()
        event_cals = [c for c in cals if c.get("holdsEvents", True) and not c.get("holdsTasks")]
        task_cals = [c for c in cals if c.get("holdsTasks")]
        default_event_cal_id = event_cals[0]["id"] if event_cals else (cals[0]["id"] if cals else "")
        default_task_cal_id = task_cals[0]["id"] if task_cals else (cals[0]["id"] if cals else "")

        created_events = 0
        created_tasks = 0
        errors = []

        for ev in payload.get("events", []):
            summary = (ev.get("title") or ev.get("summary") or "").strip()
            start = ev.get("start")
            end = ev.get("end") or start
            if not summary or not start:
                continue
            all_day = bool(ev.get("allDay", False))
            loc = ev.get("location", "")
            cal_id = ev.get("calendarId") or default_event_cal_id
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
            cal_id = t.get("calendarId") or default_task_cal_id
            p = int(t.get("priority", 0))
            due = t.get("due")
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

    def classify_unclassified_tasks(self, tasks_list: Optional[List[Dict[str, Any]]] = None, model_override: Optional[str] = None, include_completed: bool = False) -> List[Dict[str, Any]]:
        if tasks_list is None:
            summary = self.get_tasks_summary()
            all_pool = list(summary.get("pending", []))
            if include_completed:
                all_pool.extend(summary.get("completed", []))
            tasks_list = [t for t in all_pool if not t.get("tags")]

        return TaskClassifier.classify_batch(tasks_list, model_override=model_override)

    def apply_tags_updates(self, updates: List[Dict[str, Any]]) -> Dict[str, Any]:
        success_count = 0
        errors = []
        for item in updates:
            tid = str(item.get("id") or "")
            tagged_sum = item.get("taggedSummary") or item.get("summary")
            if not tid or not tagged_sum:
                continue
            ok = self.dcal.update_task(tid, summary=tagged_sum)
            if ok:
                success_count += 1
            else:
                errors.append(f"Failed to update task {tid}")
        return {
            "success": len(errors) == 0,
            "updatedCount": success_count,
            "errors": errors
        }
