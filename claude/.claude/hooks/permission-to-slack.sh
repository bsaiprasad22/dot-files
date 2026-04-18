#!/usr/bin/env bash
# PermissionRequest hook: write permission prompt details to a file
# for the orchestrator to pick up and post to Slack.

set -euo pipefail

SLACK_OPS_DIR="$HOME/.local/share/slack-ops"
input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // "unknown"')
description=$(echo "$input" | jq -r '.tool_input.description // empty')
command=$(echo "$input" | jq -r '.tool_input.command // .tool_input.file_path // .tool_input.path // empty')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // "unknown"')

# Determine tmux session name from cwd or session_id
tmux_session=$(tmux display-message -p '#S' 2>/dev/null || echo "unknown")

# Skip if this is the orchestrator itself
[[ "$tmux_session" == "claude-ops" ]] && exit 0

# Write pending prompt file for orchestrator to pick up
mkdir -p "$SLACK_OPS_DIR"
cat > "$SLACK_OPS_DIR/pending-prompt-${tmux_session}.json" << EOF
{
  "tmux_session": "$tmux_session",
  "tool_name": "$tool_name",
  "command": $(echo "$command" | jq -Rs .),
  "description": $(echo "$description" | jq -Rs .),
  "cwd": "$cwd",
  "timestamp": "$(date -Iseconds)"
}
EOF
