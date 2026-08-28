"""
paste_service.py
Service for caching clipboard image captures to XDG cache directory.
"""

import os
import sys
import subprocess
import time
from typing import Optional

XDG_CACHE_HOME = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
PASTE_DIR = os.path.join(XDG_CACHE_HOME, "dms-ai", "paste")

class PasteService:
    @staticmethod
    def ensure_dir():
        os.makedirs(PASTE_DIR, mode=0o700, exist_ok=True)

    @classmethod
    def capture_clipboard_image(cls) -> Optional[str]:
        cls.ensure_dir()
        ts = int(time.time() * 1000)
        target_path = os.path.join(PASTE_DIR, f"paste_{ts}.png")

        # Try wl-paste
        try:
            res = subprocess.run(["wl-paste", "--type", "image/png"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=2)
            if res.returncode == 0 and len(res.stdout) > 0:
                with open(target_path, "wb") as f:
                    f.write(res.stdout)
                return target_path
        except Exception:
            pass

        # Try xclip
        try:
            res = subprocess.run(["xclip", "-selection", "clipboard", "-t", "image/png", "-o"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=2)
            if res.returncode == 0 and len(res.stdout) > 0:
                with open(target_path, "wb") as f:
                    f.write(res.stdout)
                return target_path
        except Exception:
            pass

        return None
