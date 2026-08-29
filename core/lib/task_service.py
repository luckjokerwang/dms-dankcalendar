import os
import sqlite3
from typing import Dict, Any, List, Optional
from .dcal_client import DcalClient
from .types import TasksListResult, TaskItem

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
        pending: List[TaskItem] = []
        completed: List[TaskItem] = []

        for t in all_tasks:
            t["calendarName"] = cal_map.get(t.get("calendarId", ""), "Tasks")
            if t.get("id") and t.get("id") in created_map:
                t["created"] = created_map[t["id"]]
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

        return {
            "pending": sorted_pending,
            "completed": completed,
            "pendingCount": len(sorted_pending),
            "completedCount": len(completed),
            "defaultCalendarId": default_cal_id,
            "taskCalendars": [{"id": c["id"], "name": c.get("name") or "Tasks"} for c in task_cals]
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
            "errors": errors,
            "success": len(errors) == 0
        }
