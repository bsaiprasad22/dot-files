#!/usr/bin/env bash
# Claude Code notification script
# Sends bell + OSC 9 toast notification to WezTerm
# Works through tmux (including detached sessions on reattach)

# Read notification data from stdin (JSON from Claude Code hook)
input=$(cat)
notification_type=$(echo "$input" | jq -r '.notification_type // "unknown"' 2>/dev/null)

# Human-readable message
case "$notification_type" in
  permission_prompt) msg="Needs permission to proceed" ;;
  idle_prompt)       msg="Done — waiting for input" ;;
  elicitation_dialog) msg="Asking you a question" ;;
  auth_success)      msg="Authentication complete" ;;
  *)                 msg="Needs your attention" ;;
esac

# Only send toast notifications when inside tmux
[ -z "$TMUX" ] && exit 0

label=$(tmux display-message -p '#S')
tty=$(tmux display-message -p '#{pane_tty}')

# Send OSC 9 toast via DCS passthrough (tmux 3.2+)
printf '\ePtmux;\e\033]9;%s: %s\a\e\\' "$label" "$msg" > "$tty" 2>/dev/null

# Also display a tmux message (visible when attached)
tmux display-message "Claude Code: $msg" 2>/dev/null
