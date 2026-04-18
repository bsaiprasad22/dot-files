#!/usr/bin/env bash
# Stop hook: write Claude's response to a file for the orchestrator
# to post to Slack. Only fires for sessions connected to Slack.

set -euo pipefail

SLACK_OPS_DIR="$HOME/.local/share/slack-ops"
REGISTRY="$SLACK_OPS_DIR/registry.json"

input=$(cat)

# Get tmux session name
tmux_session=$(tmux display-message -p '#S' 2>/dev/null || echo "")
[[ -z "$tmux_session" ]] && exit 0

# Skip orchestrator
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

# Write pending response for orchestrator to post
mkdir -p "$SLACK_OPS_DIR"
cat > "$SLACK_OPS_DIR/pending-response-${tmux_session}.txt" <<< "$response"
