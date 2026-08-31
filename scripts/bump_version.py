#!/usr/bin/env python3
"""
bump_version.py
Helper script to bump semantic version (x.y.z) across all project configuration files.
"""

import sys
import os
import re
import json

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGIN_JSON_PATH = os.path.join(ROOT_DIR, "plugin.json")
README_MD_PATH = os.path.join(ROOT_DIR, "README.md")

def get_current_version() -> str:
    if not os.path.exists(PLUGIN_JSON_PATH):
        raise FileNotFoundError(f"plugin.json not found at {PLUGIN_JSON_PATH}")
    with open(PLUGIN_JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data.get("version", "0.0.0")

def parse_semver(ver: str):
    m = re.match(r"^(\d+)\.(\d+)\.(\d+)(.*)$", ver.strip())
    if not m:
        raise ValueError(f"Invalid semver version: '{ver}'. Expected format: x.y.z")
    return int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)

def calculate_new_version(current: str, bump_type: str) -> str:
    bump_type = bump_type.strip().lower()
    major, minor, patch, extra = parse_semver(current)

    if bump_type in ("patch", "p"):
        return f"{major}.{minor}.{patch + 1}"
    elif bump_type in ("minor", "m"):
        return f"{major}.{minor + 1}.0"
    elif bump_type in ("major", "M"):
        return f"{major + 1}.0.0"
    else:
        # Check if user provided an explicit version string
        parse_semver(bump_type)
        return bump_type

def update_plugin_json(new_ver: str):
    if not os.path.exists(PLUGIN_JSON_PATH):
        return
    with open(PLUGIN_JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    data["version"] = new_ver
    with open(PLUGIN_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

def update_readme_md(new_ver: str):
    if not os.path.exists(README_MD_PATH):
        return
    with open(README_MD_PATH, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Replace Version badge: [![Version](https://img.shields.io/badge/Version-v3.1.3-brightgreen.svg)]
    new_badge = f"[![Version](https://img.shields.io/badge/Version-v{new_ver}-brightgreen.svg)]"
    updated_content = re.sub(
        r'\[!\[Version\]\(https://img\.shields\.io/badge/Version-v[0-9a-zA-Z\.\-]+-brightgreen\.svg\)\]',
        new_badge,
        content
    )
    with open(README_MD_PATH, "w", encoding="utf-8") as f:
        f.write(updated_content)

def main():
    if len(sys.argv) < 2:
        current = get_current_version()
        print(f"Current version: {current}")
        print("Usage: python3 bump_version.py [patch|minor|major|<x.y.z>]")
        sys.exit(0)

    arg = sys.argv[1]
    if arg in ("current", "--current", "-v"):
        print(get_current_version())
        sys.exit(0)

    current_ver = get_current_version()
    new_ver = calculate_new_version(current_ver, arg)

    update_plugin_json(new_ver)
    update_readme_md(new_ver)

    print(f"Successfully bumped version: {current_ver} -> {new_ver}")

if __name__ == "__main__":
    main()
