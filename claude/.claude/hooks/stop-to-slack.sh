#!/usr/bin/env bash
# Stop hook: write Claude's response to a file for the bot to post to Slack.
# Only fires for sessions registered as active in the slack-ops registry.

set -euo pipefail

SLACK_OPS_DIR="$HOME/.local/share/slack-ops"
REGISTRY="$SLACK_OPS_DIR/registry.json"

[[ ! -f "$REGISTRY" ]] && exit 0

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)
response=$(jq -r '.last_assistant_message // empty' <<<"$input" 2>/dev/null || true)

# Resolve tmux_session: prefer registry match by cwd, fall back to $TMUX.
# Single registry read; safe env-var passing (no shell interpolation).
resolved=$(CWD="$cwd" TMUX_ENV="${TMUX:-}" python3 <<'PY'
import json, os, sys, subprocess

cwd = os.environ.get("CWD", "")
registry_path = os.path.expanduser("~/.local/share/slack-ops/registry.json")

try:
    reg = json.load(open(registry_path))
except Exception:
    sys.exit(0)

def emit(session):
    print(session)
    sys.exit(0)

# 1. Match active session by cwd (worktree path or session name in cwd)
for k, v in reg.items():
    if v.get("status") != "active":
        continue
    ts = v.get("tmux_session", k)
    jira = v.get("jira_id") or ""
    if (jira and cwd.endswith(jira)) or (ts and ts in cwd):
        emit(ts)

# 2. Fall back to $TMUX → live tmux session name
if os.environ.get("TMUX_ENV"):
    try:
        ts = subprocess.check_output(
            ["tmux", "display-message", "-p", "#S"],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        ts = ""
    if ts:
        for v in reg.values():
            if v.get("tmux_session") == ts and v.get("status") == "active":
                emit(ts)
PY
)

[[ -z "$resolved" ]] && exit 0
[[ "$resolved" == "claude-ops" ]] && exit 0
[[ -z "$response" ]] && exit 0

mkdir -p "$SLACK_OPS_DIR"
printf '%s\n' "$response" > "$SLACK_OPS_DIR/pending-response-${resolved}.txt"
