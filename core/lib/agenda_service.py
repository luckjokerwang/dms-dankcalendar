"""
agenda_service.py
Service for calendar agenda queries, window calculation, and next-event countdown extraction.
"""

import datetime
from typing import Dict, Any, List, Optional
from .dcal_client import DcalClient
from .types import EventItem, NextEventResult

from .tag_service import TagService

class AgendaService:
    def __init__(self, dcal: Optional[DcalClient] = None):
        self.dcal = dcal or DcalClient()

    def get_agenda_events(self, past_days: int = 7, future_days: int = 30) -> List[Dict[str, Any]]:
        now_local = datetime.datetime.now().astimezone()
        start_local = (now_local - datetime.timedelta(days=past_days)).replace(hour=0, minute=0, second=0, microsecond=0)
        end_local = (now_local + datetime.timedelta(days=future_days)).replace(hour=23, minute=59, second=59, microsecond=0)

        from_iso = start_local.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        to_iso = end_local.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        events = self.dcal.get_events(from_iso, to_iso)
        tag_map = TagService.get_tag_map()
        for ev in events:
            raw_summary = ev.get("summary") or ""
            clean_sum, tags = TagService.parse_tags_detail(raw_summary, tag_map=tag_map)
            ev["cleanSummary"] = clean_sum
            ev["tags"] = tags
        return events

    def get_next_event(self, look_ahead_days: int = 1, now_window_mins: int = 5) -> Optional[NextEventResult]:
        now_local = datetime.datetime.now().astimezone()
        start_local = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
        end_local = (now_local + datetime.timedelta(days=look_ahead_days)).replace(hour=23, minute=59, second=59, microsecond=0)

        from_iso = start_local.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        to_iso = end_local.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        events = self.dcal.get_events(from_iso, to_iso)
        if not events:
            return None

        # Helper to parse event start
        def parse_start(ev: Dict[str, Any]) -> Optional[datetime.datetime]:
            s = ev.get("start")
            if not s:
                return None
            try:
                # Handle iso format
                clean_s = s.replace("Z", "+00:00")
                dt = datetime.datetime.fromisoformat(clean_s)
                if ev.get("allDay"):
                    # Local midnight
                    return dt.astimezone().replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=None)
                if dt.tzinfo:
                    return dt.astimezone().replace(tzinfo=None)
                return dt
            except Exception:
                return None

        valid_events = []
        for ev in events:
            st = parse_start(ev)
            if not st:
                continue
            valid_events.append((st, ev))

        valid_events.sort(key=lambda x: x[0])
        now_clean = now_local.replace(microsecond=0, tzinfo=None)
        tag_map = TagService.get_tag_map()

        for st, ev in valid_events:
            raw_summary = ev.get("summary") or ""
            clean_sum, tags = TagService.parse_tags_detail(raw_summary, tag_map=tag_map)
            if st >= now_clean:
                return {
                    "summary": raw_summary,
                    "cleanSummary": clean_sum,
                    "tags": tags,
                    "start": ev.get("start") or "",
                    "end": ev.get("end") or "",
                    "allDay": bool(ev.get("allDay", False)),
                    "location": ev.get("location") or "",
                    "description": ev.get("description") or "",
                    "meetingUrl": ev.get("meetingUrl") or "",
                    "url": ev.get("url") or ""
                }
            # Or currently happening
            if now_window_mins > 0 and (now_clean - st).total_seconds() <= (now_window_mins * 60):
                return {
                    "summary": raw_summary,
                    "cleanSummary": clean_sum,
                    "tags": tags,
                    "start": ev.get("start") or "",
                    "end": ev.get("end") or "",
                    "allDay": bool(ev.get("allDay", False)),
                    "location": ev.get("location") or "",
                    "description": ev.get("description") or "",
                    "meetingUrl": ev.get("meetingUrl") or "",
                    "url": ev.get("url") or ""
                }

        return None
