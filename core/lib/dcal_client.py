"""
dcal_client.py
Robust dcal IPC client wrapper with timeout, security argument escaping, and error handling.
"""

import subprocess
import json
from typing import List, Dict, Any, Optional

class DcalClient:
    def __init__(self, timeout: float = 4.0):
        self.timeout = timeout

    def call(self, method: str, *args: str) -> Optional[Any]:
        cmd = ["dcal", "ipc", method] + list(args)
        try:
            proc = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=self.timeout
            )
            if proc.returncode != 0:
                return None
            out = proc.stdout.strip()
            if not out:
                return {"status": "ok"}
            try:
                return json.loads(out)
            except json.JSONDecodeError:
                return {"status": "ok", "raw": out}
        except Exception:
            return None

    def get_calendars(self) -> List[Dict[str, Any]]:
        res = self.call("calendars.list")
        if isinstance(res, list):
            return res
        if isinstance(res, dict) and "calendars" in res:
            return res["calendars"]
        return []

    def get_tasks(self) -> List[Dict[str, Any]]:
        res = self.call("tasks.list")
        if isinstance(res, dict) and "tasks" in res:
            return res["tasks"]
        if isinstance(res, list):
            return res
        return []

    def get_events(self, from_iso: str, to_iso: str) -> List[Dict[str, Any]]:
        res = self.call("events.list", f"from={from_iso}", f"to={to_iso}")
        if isinstance(res, dict) and "events" in res:
            return res["events"]
        if isinstance(res, list):
            return res
        return []

    def create_task(self, calendar_id: str, summary: str, priority: int = 0, due: Optional[str] = None) -> bool:
        args = [f"calendarId={calendar_id}", f"summary={summary}"]
        if priority > 0:
            args.append(f"priority={priority}")
        if due:
            args.append(f"due={due}")
        res = self.call("tasks.create", *args)
        return res is not None

    def complete_task(self, task_id: str, completed: bool = True) -> bool:
        val = "true" if completed else "false"
        res = self.call("tasks.complete", f"id={task_id}", f"completed={val}")
        return res is not None

    def delete_task(self, task_id: str) -> bool:
        res = self.call("tasks.delete", f"id={task_id}")
        return res is not None

    def create_event(self, calendar_id: str, summary: str, start_iso: str, end_iso: str, all_day: bool = False, location: str = "") -> bool:
        args = [
            f"calendarId={calendar_id}",
            f"summary={summary}",
            f"start={start_iso}",
            f"end={end_iso}"
        ]
        if all_day:
            args.append("allDay=true")
        if location:
            args.append(f"location={location}")
        res = self.call("events.create", *args)
        return res is not None

    def delete_event(self, event_id: str, occurrence_start: Optional[str] = None) -> bool:
        args = [f"id={event_id}"]
        if occurrence_start:
            args.append(f"occurrenceStart={occurrence_start}")
        res = self.call("events.delete", *args)
        return res is not None
