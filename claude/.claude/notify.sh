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

# Build context label: hostname + tmux session/window if available
host=$(hostname -s)
if [ -n "$TMUX" ]; then
  sess=$(tmux display-message -p '#S:#W')
  label="[$host/$sess]"
else
  label="[$host]"
fi

# Determine the TTY to write to
if [ -n "$TMUX" ]; then
  tty=$(tmux display-message -p '#{pane_tty}')
else
  tty=$(tty 2>/dev/null)
  [ "$tty" = "not a tty" ] && tty=/dev/tty
fi

# Send OSC 9 toast notification (WezTerm native)
if [ -n "$TMUX" ]; then
  # tmux 3.2: wrap OSC in DCS passthrough so it reaches WezTerm
  printf '\ePtmux;\e\033]9;Claude Code %s: %s\a\e\\' "$label" "$msg" > "$tty" 2>/dev/null
else
  printf '\033]9;Claude Code %s: %s\a' "$label" "$msg" > "$tty" 2>/dev/null
fi

# If in tmux, also display a tmux message (visible when attached)
if [ -n "$TMUX" ]; then
  tmux display-message "Claude Code: $msg" 2>/dev/null
fi
