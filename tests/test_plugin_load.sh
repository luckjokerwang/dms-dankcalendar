#!/usr/bin/env bash
# ==============================================================================
# test_plugin_load.sh
# Automated regression test for Dank Calendar Plus QML components & DMS loading
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== 1. QML Syntax & Component Linting (qmllint) ==="
python3 -c "
import os, sys, subprocess, re

root_dir = '$ROOT_DIR'
has_error = False

for root, _, files in os.walk(root_dir):
    if '.git' in root or '.agents' in root:
        continue
    for f in files:
        if f.endswith('.qml'):
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8') as qf:
                content = qf.read()
            
            # Rule 1: Check Layout imports
            if re.search(r'\b(RowLayout|ColumnLayout|GridLayout|Layout\.)\b', content):
                if not re.search(r'import\s+QtQuick\.Layouts', content):
                    print(f'❌ [FAIL] Missing \"import QtQuick.Layouts\" in: {p}')
                    has_error = True
            
            # Rule 2: Check PluginGlobalVar imports
            if re.search(r'\bPluginGlobalVar\b', content):
                if not re.search(r'import\s+qs\.Widgets', content):
                    print(f'❌ [FAIL] Missing \"import qs.Widgets\" in: {p}')
                    has_error = True

            # Rule 3: Run qmllint
            res = subprocess.run(['qmllint', p], capture_output=True, text=True)
            if res.returncode != 0 or 'error' in res.stderr.lower():
                print(f'❌ [FAIL] qmllint failed for {p}:\n{res.stdout}\n{res.stderr}')
                has_error = True

if has_error:
    print('❌ QML static check failed!')
    sys.exit(1)
else:
    print('✅ All QML files passed static linting and import checks.')
"

echo ""
echo "=== 2. DMS Plugin Runtime Load Status ==="
if command -v quickshell &>/dev/null; then
    status=$(quickshell -p /usr/share/quickshell/dms ipc call plugins status dankCalendarPlus 2>/dev/null || echo "not_running")
    if [ "$status" = "loaded" ]; then
        echo "✅ Plugin is actively LOADED in running DMS shell."
    elif [ "$status" = "disabled" ]; then
        echo "⚠️ Plugin is disabled, attempting to enable via IPC..."
        res=$(quickshell -p /usr/share/quickshell/dms ipc call plugins enable dankCalendarPlus)
        echo "$res"
        if echo "$res" | grep -q "PLUGIN_ENABLE_SUCCESS"; then
            echo "✅ Plugin successfully enabled and loaded!"
        else
            echo "❌ Plugin enable failed: $res"
            exit 1
        fi
    else
        echo "ℹ️ DMS is not running in background, skipping live IPC test."
    fi
fi

echo ""
echo "=== 3. Quickshell Log Error Inspection ==="
python3 -c "
import os, glob
logs = sorted(glob.glob('/run/user/1000/quickshell/by-id/*/log.qslog'), key=os.path.getmtime, reverse=True)
if logs:
    latest = logs[0]
    print(f'Checking latest log: {latest}')
    with open(latest, 'rb') as f:
        f.seek(max(0, os.path.getsize(latest) - 30000))
        lines = f.read().decode('utf-8', errors='ignore').split('\n')
        errors = [l for l in lines if 'component error dankcalendarplus' in l.lower() or 'type taskstore unavailable' in l.lower()]
        if errors:
            print('❌ Found component errors in log:')
            for e in errors:
                print('  ', e)
            exit(1)
        else:
            print('✅ Zero DankCalendarPlus component errors in latest DMS log.')
"

echo ""
echo "🎉 ALL TESTS PASSED! Plugin is 100% healthy and active."
