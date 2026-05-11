#!/usr/bin/env bash
# Stop hook: write Claude's response to a file for the bot to post to Slack.
# Only fires for sessions connected to Slack (checked against registry).

set -euo pipefail

SLACK_OPS_DIR="$HOME/.local/share/slack-ops"
REGISTRY="$SLACK_OPS_DIR/registry.json"

input=$(cat)

# Get tmux session name — try multiple methods
tmux_session=""

# Method 1: $TMUX env var is set
if [[ -n "${TMUX:-}" ]]; then
    tmux_session=$(tmux display-message -p '#S' 2>/dev/null || echo "")
fi

# Method 2: walk up the process tree to find the tmux pane
if [[ -z "$tmux_session" ]]; then
    pid=$$
    for _ in $(seq 1 10); do
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [[ -z "$ppid" || "$ppid" == "1" ]] && break
        # Check if this process is a tmux client/server
        pane_tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
        if [[ -n "$pane_tty" && "$pane_tty" != "?" ]]; then
            tmux_session=$(tmux list-panes -a -F '#{pane_tty} #{session_name}' 2>/dev/null | grep "$pane_tty" | awk '{print $2}' | head -1)
            [[ -n "$tmux_session" ]] && break
        fi
        pid=$ppid
    done
fi

# Method 3: derive from cwd — match worktree path to registry
if [[ -z "$tmux_session" ]]; then
    cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
    if [[ -n "$cwd" && -f "$REGISTRY" ]]; then
        tmux_session=$(python3 -c "
import json, os, sys
cwd = '$cwd'
try:
    reg = json.load(open('$REGISTRY'))
    for k, v in reg.items():
        if v.get('status') != 'active':
            continue
        # Match by worktree path
        jira = v.get('jira_id', '')
        if jira and cwd.endswith(jira):
            print(v.get('tmux_session', k))
            sys.exit(0)
        # Match by tmux session name in cwd
        ts = v.get('tmux_session', k)
        if ts in cwd:
            print(ts)
            sys.exit(0)
except:
    pass
" 2>/dev/null)
    fi
fi

[[ -z "$tmux_session" ]] && exit 0
[[ "$tmux_session" == "claude-ops" ]] && exit 0

# Check if this session is in the registry and active
[[ ! -f "$REGISTRY" ]] && exit 0
status=$(python3 -c "
import json, sys
try:
    reg = json.load(open('$REGISTRY'))
    for v in reg.values():
        if v.get('tmux_session') == '$tmux_session' and v.get('status') == 'active':
            print('connected')
            sys.exit(0)
    print('not_connected')
except:
    print('error')
" 2>/dev/null)

[[ "$status" != "connected" ]] && exit 0

# Extract response
response=$(echo "$input" | jq -r '.last_assistant_message // empty')
[[ -z "$response" ]] && exit 0

# Write pending response for bot to post
mkdir -p "$SLACK_OPS_DIR"
cat > "$SLACK_OPS_DIR/pending-response-${tmux_session}.txt" <<< "$response"
