#!/bin/bash
# Claude Code Enhanced Status Line

input=$(cat)

# Extract data
cwd=$(echo "$input" | jq -r '.cwd // empty')
session=$(echo "$input" | jq -r '.session_name // empty')
model_display=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
version=$(echo "$input" | jq -r '.version // empty')

# Context window
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Cost (provided directly by Claude Code)
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
api_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')

# Vim mode
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')

# Worktree / agent (may not always be present)
worktree=$(echo "$input" | jq -r '.worktree.name // empty')
agent=$(echo "$input" | jq -r '.agent.name // empty')

# Shorten cwd
short_dir="${cwd/#$HOME/\~}"
short_dir=$(echo "$short_dir" | awk -F'/' '{n=NF; if(n<=3) print $0; else printf ".../%s/%s",$(n-1),$n}')

# Git branch
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# Token count (human readable)
tokens=""
total=$((total_input + total_output))
if [ "$total" -gt 1000000 ]; then
  tokens=$(awk "BEGIN {printf \"%.1fM\", $total / 1000000}")
elif [ "$total" -gt 1000 ]; then
  tokens=$(awk "BEGIN {printf \"%.0fk\", $total / 1000}")
fi

# Format cost
cost=""
if [ -n "$cost_usd" ] && [ "$cost_usd" != "0" ]; then
  cost=$(awk "BEGIN {printf \"\$%.2f\", $cost_usd}")
fi

# Format duration
duration=""
if [ "$duration_ms" -gt 0 ] 2>/dev/null; then
  secs=$((duration_ms / 1000))
  if [ "$secs" -ge 3600 ]; then
    duration=$(awk "BEGIN {printf \"%.1fh\", $secs / 3600}")
  elif [ "$secs" -ge 60 ]; then
    duration=$(awk "BEGIN {printf \"%.0fm\", $secs / 60}")
  else
    duration="${secs}s"
  fi
fi

# Build output
out=""

# Directory
out+="\033[2mdir:\033[0m\033[32m${short_dir}\033[0m"

# Git branch
[ -n "$branch" ] && out+=" \033[2mbr:\033[0m\033[36m${branch}\033[0m"

# Worktree
[ -n "$worktree" ] && out+=" \033[2mwt:\033[0m\033[33m${worktree}\033[0m"

# Agent
[ -n "$agent" ] && out+=" \033[2magent:\033[0m\033[34m${agent}\033[0m"

# Session
[ -n "$session" ] && out+=" \033[2msession:\033[0m${session}"

# Separator
out+=" \033[2m|\033[0m"

# Model (shortened)
model_short=$(echo "$model_display" | sed 's/Claude-//; s/\[1m\]//')
out+=" \033[2mmodel:\033[0m\033[36m${model_short}\033[0m"

# Context remaining (color-coded)
if [ -n "$remaining" ]; then
  pct=${remaining%.*}
  if [ "$pct" -ge 50 ] 2>/dev/null; then
    color="32"  # green
  elif [ "$pct" -ge 20 ] 2>/dev/null; then
    color="33"  # yellow
  else
    color="31"  # red
  fi
  out+=" \033[2mctx:\033[0m\033[${color}m${pct}%\033[0m"
fi

# Tokens used
[ -n "$tokens" ] && out+=" \033[2mtok:\033[0m${tokens}"

# Cost
[ -n "$cost" ] && out+=" \033[2mcost:\033[0m\033[33m${cost}\033[0m"

# Session duration
[ -n "$duration" ] && out+=" \033[2mtime:\033[0m${duration}"

# Vim mode
[ -n "$vim_mode" ] && out+=" \033[2m|\033[0m \033[1;31m--${vim_mode}--\033[0m"

echo -e "$out"
