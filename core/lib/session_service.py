"""
session_service.py
Service for conversation session persistence, listing, retrieval, and smart title naming.
"""

import os
import json
import re
import datetime
from typing import Dict, Any, List, Optional
from .types import SessionItem

XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
SESSIONS_DIR = os.path.join(XDG_DATA_HOME, "dms-dankcalendar", "sessions")

class SessionService:
    @staticmethod
    def ensure_dir():
        os.makedirs(SESSIONS_DIR, mode=0o700, exist_ok=True)

    @classmethod
    def get_session_file(cls, session_id: str) -> str:
        safe_id = "".join(c for c in session_id if c.isalnum() or c in ("-", "_"))
        return os.path.join(SESSIONS_DIR, f"{safe_id}.json")

    @classmethod
    def list_sessions(cls) -> List[Dict[str, Any]]:
        cls.ensure_dir()
        sessions = []
        for fname in os.listdir(SESSIONS_DIR):
            if fname.endswith(".json"):
                fpath = os.path.join(SESSIONS_DIR, fname)
                try:
                    with open(fpath, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        sessions.append({
                            "id": data.get("id") or fname[:-5],
                            "title": data.get("title") or "新排程会话",
                            "updatedAt": data.get("updatedAt") or "",
                            "messageCount": len(data.get("messages", []))
                        })
                except Exception:
                    pass

        sessions.sort(key=lambda s: s.get("updatedAt", ""), reverse=True)
        return sessions

    @classmethod
    def get_session(cls, session_id: str) -> Optional[SessionItem]:
        cls.ensure_dir()
        fpath = cls.get_session_file(session_id)
        if not os.path.exists(fpath):
            return None
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return None

    @classmethod
    def save_session(cls, session: Dict[str, Any]) -> bool:
        cls.ensure_dir()
        s_id = session.get("id")
        if not s_id:
            return False
        fpath = cls.get_session_file(s_id)
        session["updatedAt"] = datetime.datetime.now().isoformat()
        try:
            with open(fpath, "w", encoding="utf-8") as f:
                json.dump(session, f, indent=2, ensure_ascii=False)
            return True
        except Exception:
            return False

    @classmethod
    def delete_session(cls, session_id: str) -> bool:
        cls.ensure_dir()
        fpath = cls.get_session_file(session_id)
        if os.path.exists(fpath):
            try:
                os.remove(fpath)
                return True
            except Exception:
                return False
        return True

    @classmethod
    def generate_smart_title(cls, session_id: str, prompt: str, proposal: Optional[Dict[str, Any]], messages: List[Dict[str, Any]]) -> str:
        # Check proposal title first
        if proposal and isinstance(proposal, dict):
            prop_title = proposal.get("title", "").strip()
            if prop_title:
                clean = re.sub(r"^[^\w\u4e00-\u9fa5]+", "", prop_title)
                if 2 <= len(clean) <= 16:
                    return clean

        # Extract from prompt keywords
        clean_p = prompt.strip()
        lines = clean_p.splitlines()
        first_line = lines[0].strip() if lines else ""
        first_line = re.sub(r"^(帮我|请帮我|安排|规划|制定|添加|创建)\s*", "", first_line)
        if 2 <= len(first_line) <= 12:
            return first_line
        if len(first_line) > 12:
            return first_line[:10] + "..."

        return "新排程会话"
