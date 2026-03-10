# claude-session-cleanup

Clean stale Claude Code session data across all artifact locations.

## Problem

Claude Code accumulates session artifacts in 8+ locations under `~/.claude/` and `/tmp/`. Over time this grows to hundreds of stale sessions and thousands of orphaned temp files. There's no built-in cleanup tool.

## Install

Already installed at `~/bin/claude-session-cleanup`. Ensure `~/bin` is in PATH:

```bash
export PATH="$HOME/bin:$PATH"  # added to ~/.zshrc
```

## Usage

```bash
# Preview what would be cleaned (no deletions)
claude-session-cleanup --dry-run

# Interactive cleanup (default 7-day stale threshold)
claude-session-cleanup

# Auto-clean everything stale, no prompts
claude-session-cleanup --force

# Custom stale threshold (e.g. 3 days)
claude-session-cleanup -d 3

# Combine flags
claude-session-cleanup --dry-run -d 14
```

## Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be deleted, don't act |
| `-f`, `--force` | Non-interactive, delete all stale + orphaned |
| `-d N`, `--days N` | Stale threshold in days (default: 7) |
| `-h`, `--help` | Usage info |
| `-v`, `--version` | Version |

## What it scans

| Location | Contents |
|----------|----------|
| `~/.claude/projects/*/UUID.jsonl` | Conversation logs |
| `~/.claude/projects/*/UUID/` | Subagent/tool-result dirs |
| `~/.claude/session-env/UUID/` | Session environment |
| `~/.claude/todos/UUID-agent-*.json` | Todo files |
| `~/.claude/tasks/UUID/` | Task dirs |
| `~/.claude/debug/UUID.txt` | Debug logs |
| `~/.claude/file-history/UUID/` | File history |
| `~/.claude/history.jsonl` | Session history entries |
| `/tmp/claude-*-cwd` | Orphaned tmp files |
| `~/.claude/projects/*/agent-*.jsonl` | Old-format agent logs |

## Session classification

| Status | Criteria | Eligible for cleanup |
|--------|----------|---------------------|
| **ACTIVE** | session-env mtime < 12h AND a `claude` process is running | No |
| **RECENT** | Last activity within stale threshold (default 7 days) | No |
| **STALE** | Last activity older than threshold | Yes |

Orphaned `/tmp` files are detected by checking if the PID encoded in the filename is still running.

## Interactive mode

When run without `--force`, prompts for each category:

```
Clean stale sessions? [y/N/select]
  y      — delete all stale
  select — pick individual sessions
  N      — skip
```

Orphaned `/tmp` and old agent logs are prompted separately (default: yes).

## Safety

- `history.jsonl` is backed up to `~/.claude/backups/` before any modification
- Active sessions are never touched
- Recent sessions are shown but excluded from cleanup
- `--dry-run` performs zero deletions
- `/tmp` files are only removed if their PID is dead

## Dependencies

- bash 4+ (associative arrays)
- python3 (history.jsonl filtering only)
- Standard coreutils: `stat`, `du`, `date`, `bc`, `pgrep`
