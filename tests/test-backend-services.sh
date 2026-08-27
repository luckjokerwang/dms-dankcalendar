#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_tmp=$(mktemp -d)
trap 'rm -rf -- "$test_tmp"' EXIT

export XDG_DATA_HOME="$test_tmp/data"
export XDG_CONFIG_HOME="$test_tmp/config"
export XDG_CACHE_HOME="$test_tmp/cache"

echo "=== 1. Testing session-manager with isolated XDG_DATA_HOME ==="
# Test save session
"$repo_dir/session-manager" save '{"id":"test-session-1","title":"测试会话 1","messages":[{"role":"user","content":"你好"}]}' > "$test_tmp/save_res.json"
grep -q '"status": "ok"' "$test_tmp/save_res.json" || { echo "Session save failed"; exit 1; }

# Verify file exists under XDG_DATA_HOME/dms-dankcalendar/sessions/
test -f "$test_tmp/data/dms-dankcalendar/sessions/test-session-1.json" || { echo "Session file not found in XDG path"; exit 1; }

# Test list sessions
"$repo_dir/session-manager" list > "$test_tmp/list_res.json"
grep -q "test-session-1" "$test_tmp/list_res.json" || { echo "Session list failed to find session"; exit 1; }

# Test get session
"$repo_dir/session-manager" get "test-session-1" > "$test_tmp/get_res.json"
grep -q "测试会话 1" "$test_tmp/get_res.json" || { echo "Session get failed"; exit 1; }

# Test delete session
"$repo_dir/session-manager" delete "test-session-1" > /dev/null
test ! -f "$test_tmp/data/dms-dankcalendar/sessions/test-session-1.json" || { echo "Session delete failed to remove file"; exit 1; }

echo "session-manager tests: ok"

echo "=== 2. Testing provider-manager permissions & config ==="
# Test list and save
"$repo_dir/provider-manager" list > "$test_tmp/prov_list.json"
grep -q '"status": "ok"' "$test_tmp/prov_list.json" || { echo "Provider list failed"; exit 1; }

# Verify permissions
conf_file="$HOME/.config/dms-ai/providers.json"
if [ -f "$conf_file" ]; then
    perm=$(stat -c "%a" "$conf_file")
    if [ "$perm" != "600" ]; then
        echo "Warning: permissions on $conf_file are $perm (expected 600)"
        exit 1
    fi
fi

echo "provider-manager tests: ok"

echo "=== 3. Testing clipboard-paste-helper cache dir ==="
"$repo_dir/clipboard-paste-helper" > /dev/null
test -d "$test_tmp/cache/dms-ai/paste" || { echo "Cache directory not created"; exit 1; }

echo "clipboard-paste-helper tests: ok"

echo "=== 4. Testing batch-create-items with fake dcal ==="
fake_bin="$test_tmp/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/dcal" <<'SH'
#!/usr/bin/env bash
if [ "$1" = "ipc" ] && [ "$2" = "calendars.list" ]; then
  echo '[{"id":"cal-1","name":"Default","holdsTasks":true}]'
  exit 0
fi
if [ "$1" = "ipc" ] && [ "$2" = "tasks.create" ]; then
  echo '{"status":"ok","id":"task-101"}'
  exit 0
fi
echo '{"status":"ok"}'
SH
chmod +x "$fake_bin/dcal"

payload='{"events":[],"tasks":[{"summary":"测试待办注入 $(whoami) `id`","priority":1}]}'
res=$(PATH="$fake_bin:$PATH" "$repo_dir/batch-create-items" "$payload")
echo "$res" | grep -q '"status": "ok"' || { echo "batch-create-items failed: $res"; exit 1; }

echo "batch-create-items tests: ok"

echo "All backend service tests passed successfully!"
