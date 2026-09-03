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
        self.last_error: Optional[str] = None

    def call_raw(self, method: str, *args: str) -> tuple[Optional[Any], Optional[str]]:
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
                err_msg = (proc.stderr or proc.stdout or "").strip()
                self.last_error = err_msg or f"命令退出码异常: {proc.returncode}"
                return None, self.last_error
            out = proc.stdout.strip()
            if not out:
                return {"status": "ok"}, None
            try:
                return json.loads(out), None
            except json.JSONDecodeError:
                return {"status": "ok", "raw": out}, None
        except subprocess.TimeoutExpired:
            self.last_error = f"dcal IPC 调用超时 ({self.timeout}s)"
            return None, self.last_error
        except Exception as e:
            self.last_error = str(e)
            return None, self.last_error

    def call(self, method: str, *args: str) -> Optional[Any]:
        res, _ = self.call_raw(method, *args)
        return res

    @staticmethod
    def _format_error(raw_err: Optional[str]) -> str:
        if not raw_err:
            return "未知 IPC 错误"
        err_lower = raw_err.lower()
        if "eof" in err_lower or "connection reset" in err_lower or "broken pipe" in err_lower:
            return "日历同步连接中断 (EOF/连接重置)，建议检查网络代理或重启 dcal"
        if "context deadline exceeded" in err_lower or "timed out" in err_lower:
            return "日历同步请求超时"
        if "unauthorized" in err_lower or "auth" in err_lower:
            return "日历账户授权过期或未登录"
        lines = [line.strip() for line in raw_err.splitlines() if line.strip() and not line.strip().startswith("Usage:")]
        return lines[0] if lines else raw_err[:120]

    def get_calendars(self) -> List[Dict[str, Any]]:
        res = self.call("calendars.list")
        if isinstance(res, list):
            return res
        if isinstance(res, dict) and "calendars" in res:
            return res["calendars"]
        return []

    def get_tasks(self, calendar_id: Optional[str] = None) -> List[Dict[str, Any]]:
        args = [f"calendarId={calendar_id}"] if calendar_id else []
        res = self.call("tasks.list", *args)
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
        if res and isinstance(res, dict) and "id" in res and priority > 0:
            task_id = res["id"]
            try:
                import sqlite3, os
                db_path = os.path.expanduser("~/.local/share/dankcal/dankcal.db")
                if os.path.exists(db_path):
                    conn = sqlite3.connect(db_path)
                    cursor = conn.cursor()
                    cursor.execute("UPDATE tasks SET priority = ? WHERE id = ?", (priority, task_id))
                    conn.commit()
                    conn.close()
            except Exception:
                pass
        return res is not None

    def update_task_detailed(self, task_id: str, summary: Optional[str] = None, priority: Optional[int] = None, due: Optional[str] = None) -> tuple[bool, Optional[str]]:
        args = [f"id={task_id}"]
        if summary is not None:
            args.append(f"summary={summary}")
        if priority is not None:
            args.append(f"priority={priority}")
        if due is not None:
            args.append(f"due={due}")
            
        res, err = self.call_raw("tasks.update", *args)
        if res is not None:
            return True, None

        # 针对网络断开/EOF/连接重置等瞬态错误进行安全重试 1 次
        retry_keywords = ["eof", "connection reset", "broken pipe", "context canceled", "deadline exceeded"]
        if err and any(kw in err.lower() for kw in retry_keywords):
            import time
            time.sleep(0.5)
            res_retry, err_retry = self.call_raw("tasks.update", *args)
            if res_retry is not None:
                return True, None
            err = err_retry or err

        formatted_err = self._format_error(err)
        return False, formatted_err

    def update_task(self, task_id: str, summary: Optional[str] = None, priority: Optional[int] = None, due: Optional[str] = None) -> bool:
        ok, _ = self.update_task_detailed(task_id, summary=summary, priority=priority, due=due)
        return ok

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
