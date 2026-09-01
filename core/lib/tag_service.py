"""
tag_service.py
Service for cross-platform #tag categorization, SQLite tag catalog management,
color mapping, and text-based tag parsing/extraction.
"""

import os
import re
import sqlite3
from typing import Dict, Any, List, Optional, Tuple, Union

CONFIG_DIR = os.path.expanduser("~/.config/dms-ai")
TAGS_DB_PATH = os.path.join(CONFIG_DIR, "tags.db")

COLOR_PALETTE = [
    "#2563eb",  # Blue
    "#7c3aed",  # Violet
    "#db2777",  # Pink
    "#ea580c",  # Orange
    "#d97706",  # Amber
    "#16a34a",  # Green
    "#059669",  # Emerald
    "#0891b2",  # Cyan
    "#0284c7",  # Sky
    "#4f46e5",  # Indigo
    "#9333ea",  # Purple
    "#c026d3",  # Fuchsia
    "#e11d48",  # Rose
    "#546e7a"   # Slate
]

DEFAULT_PRESETS = [
    {"name": "学习", "color": "#2563eb", "icon": "school"},
    {"name": "工作", "color": "#d97706", "icon": "work"},
    {"name": "生活", "color": "#16a34a", "icon": "home"},
    {"name": "项目", "color": "#7c3aed", "icon": "folder"},
    {"name": "健康", "color": "#e11d48", "icon": "favorite"},
    {"name": "娱乐", "color": "#0891b2", "icon": "sports_esports"}
]

TAG_REGEX = re.compile(r'(?:^|\s)#([^\s#]+)')

class TagService:
    @staticmethod
    def ensure_db():
        os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)
        with sqlite3.connect(TAGS_DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tags (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT UNIQUE NOT NULL,
                    color TEXT NOT NULL DEFAULT '#546e7a',
                    icon TEXT DEFAULT 'label',
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)
            # Check if seeded
            cursor.execute("SELECT COUNT(*) FROM tags")
            count = cursor.fetchone()[0]
            if count == 0:
                for p in DEFAULT_PRESETS:
                    cursor.execute(
                        "INSERT OR IGNORE INTO tags (name, color, icon) VALUES (?, ?, ?)",
                        (p["name"], p["color"], p["icon"])
                    )
            conn.commit()

    @classmethod
    def get_connection(cls) -> sqlite3.Connection:
        cls.ensure_db()
        return sqlite3.connect(TAGS_DB_PATH)

    @classmethod
    def get_color_for_name(cls, name: str) -> str:
        """Deterministically derive a beautiful color from palette based on tag name."""
        if not name:
            return COLOR_PALETTE[0]
        hash_val = sum(ord(c) for c in name)
        return COLOR_PALETTE[hash_val % len(COLOR_PALETTE)]

    @classmethod
    def list_tags(cls) -> List[Dict[str, Any]]:
        cls.ensure_db()
        try:
            with cls.get_connection() as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute("SELECT id, name, color, icon, created_at FROM tags ORDER BY id ASC")
                rows = cursor.fetchall()
                return [dict(r) for r in rows]
        except Exception:
            return DEFAULT_PRESETS

    @classmethod
    def get_tag_map(cls) -> Dict[str, Dict[str, Any]]:
        """Returns a dict mapping tag_name -> {color, icon}."""
        tags = cls.list_tags()
        tag_map = {}
        for t in tags:
            tag_map[t["name"]] = {
                "color": t.get("color") or cls.get_color_for_name(t["name"]),
                "icon": t.get("icon") or "label"
            }
        return tag_map

    @classmethod
    def add_tag(cls, name: str, color: Optional[str] = None, icon: Optional[str] = None) -> bool:
        clean_name = name.strip().lstrip("#").strip()
        if not clean_name:
            return False
        tag_color = color or cls.get_color_for_name(clean_name)
        tag_icon = icon or "label"
        cls.ensure_db()
        try:
            with cls.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "INSERT INTO tags (name, color, icon) VALUES (?, ?, ?)",
                    (clean_name, tag_color, tag_icon)
                )
                conn.commit()
                return True
        except Exception:
            return False

    @classmethod
    def update_tag(cls, tag_id: int, name: Optional[str] = None, color: Optional[str] = None, icon: Optional[str] = None) -> bool:
        cls.ensure_db()
        updates = []
        params = []
        if name is not None:
            clean_name = name.strip().lstrip("#").strip()
            if clean_name:
                updates.append("name = ?")
                params.append(clean_name)
        if color is not None:
            updates.append("color = ?")
            params.append(color.strip())
        if icon is not None:
            updates.append("icon = ?")
            params.append(icon.strip())
        if not updates:
            return True
        params.append(tag_id)
        try:
            with cls.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(f"UPDATE tags SET {', '.join(updates)} WHERE id = ?", params)
                conn.commit()
                return cursor.rowcount > 0
        except Exception:
            return False

    @classmethod
    def delete_tag(cls, tag_id_or_name: Union[int, str]) -> bool:
        cls.ensure_db()
        try:
            with cls.get_connection() as conn:
                cursor = conn.cursor()
                if isinstance(tag_id_or_name, int) or (isinstance(tag_id_or_name, str) and tag_id_or_name.isdigit()):
                    cursor.execute("DELETE FROM tags WHERE id = ?", (int(tag_id_or_name),))
                else:
                    clean_name = str(tag_id_or_name).strip().lstrip("#").strip()
                    cursor.execute("DELETE FROM tags WHERE name = ?", (clean_name,))
                conn.commit()
                return cursor.rowcount > 0
        except Exception:
            return False

    @classmethod
    def extract_tags(cls, text: str) -> List[str]:
        """Extract all unique #tag names from text."""
        if not text:
            return []
        matches = TAG_REGEX.findall(text)
        seen = set()
        result = []
        for m in matches:
            t = m.strip()
            if t and t not in seen:
                seen.add(t)
                result.append(t)
        return result

    @classmethod
    def strip_tags(cls, text: str) -> str:
        """Remove all #tag patterns from text and clean whitespace."""
        if not text:
            return ""
        cleaned = TAG_REGEX.sub("", text)
        return re.sub(r'\s+', ' ', cleaned).strip()

    @classmethod
    def parse_tags_detail(cls, text: str, tag_map: Optional[Dict[str, Dict[str, Any]]] = None) -> Tuple[str, List[Dict[str, Any]]]:
        """
        Parse text into (clean_text, tags_list).
        Each tag item in tags_list: {"name": str, "color": str, "icon": str}
        """
        if not text:
            return "", []
        raw_tags = cls.extract_tags(text)
        clean_text = cls.strip_tags(text)
        if not raw_tags:
            return clean_text, []

        t_map = tag_map if tag_map is not None else cls.get_tag_map()
        detailed_tags = []
        for tag_name in raw_tags:
            info = t_map.get(tag_name)
            if info:
                detailed_tags.append({
                    "name": tag_name,
                    "color": info.get("color") or cls.get_color_for_name(tag_name),
                    "icon": info.get("icon") or "label"
                })
            else:
                detailed_tags.append({
                    "name": tag_name,
                    "color": cls.get_color_for_name(tag_name),
                    "icon": "label"
                })
        return clean_text, detailed_tags

    @classmethod
    def inject_tag(cls, text: str, tag_name: str) -> str:
        """Append #tag to text if not present."""
        clean_tag = tag_name.strip().lstrip("#").strip()
        if not clean_tag:
            return text
        existing = cls.extract_tags(text)
        if clean_tag in existing:
            return text
        return f"{text.rstrip()} #{clean_tag}".strip()

    @classmethod
    def remove_tag(cls, text: str, tag_name: str) -> str:
        """Remove specific #tag from text."""
        clean_tag = tag_name.strip().lstrip("#").strip()
        if not clean_tag or not text:
            return text
        pattern = re.compile(rf'(?:^|\s)#{re.escape(clean_tag)}(?=\s|$)')
        cleaned = pattern.sub("", text)
        return re.sub(r'\s+', ' ', cleaned).strip()
