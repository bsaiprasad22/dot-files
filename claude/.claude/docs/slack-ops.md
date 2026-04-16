# claude-slack-ops

Slack-driven task management for Claude Code. Dispatch tasks from Slack, interact via threads, and manage multiple concurrent Claude sessions — all from your phone.

## Architecture

```
  Slack #claude-term                    Terminal
        │                                  │
        │  "@claude INFRA-1234 ..."        │  /slack-task INFRA-1234 ...
        │                                  │        │
        ▼                                  ▼        ▼
   ┌──────────────────────────────────────────────────┐
   │  ORCHESTRATOR (tmux: claude-ops)                 │
   │  Polls Slack every 60s, spawns workers,          │
   │  routes thread replies via tmux send-keys        │
   └──────┬──────────┬──────────┬─────────────────────┘
          │          │          │
          ▼          ▼          ▼
     INFRA-1234  INFRA-1235  INFRA-1236
     (tmux ses)  (tmux ses)  (tmux ses)
     Real Claude CLI sessions, post directly to Slack
```

**Orchestrator**: long-running Claude session that polls `#claude-term`, spawns workers, routes replies.
**Workers**: real Claude CLI sessions in named tmux sessions. Full context persistence. Post directly to Slack threads.

## Prerequisites

- **Claude Code CLI** v2.1+ installed and authenticated
- **Slack MCP** configured and authenticated (OAuth, plugin: `agentq/slack`)
- **Jira MCP** configured (`pensando_jira`)
- **tmux** installed
- **GNU Stow** for dotfile management
- A Slack channel for task dispatch (default: `#claude-term`, ID: `C0ASZC1A8H4`)

### Required Settings

The following must be in `~/.claude/settings.json` (or stowed equivalent):

```json
{
  "skipDangerousModePermissionPrompt": true,
  "permissions": {
    "allow": [
      "Bash(tmux *)",
      "mcp__plugin_agentq_slack__*",
      "mcp__pensando_jira__*"
    ]
  }
}
```

These allow the orchestrator to manage tmux sessions and communicate via Slack/Jira without permission prompts.

### Slack MCP Server

Must be configured in `.mcp.json` (via agentq plugin) with OAuth:
```json
{
  "slack": {
    "type": "http",
    "url": "https://mcp.slack.com/mcp",
    "oauth": { "clientId": "...", "callbackPort": 3118 }
  }
}
```

## Setup

### 1. Stow the files

```bash
cd ~/dot-files
stow -R claude   # agents, skills, settings
stow -R bin      # helper scripts
```

### 2. Create runtime directory

```bash
mkdir -p ~/.claude/slack-ops
```

### 3. Create config

```bash
cat > ~/.claude/slack-ops/config.json << 'EOF'
{
  "channel_id": "C0ASZC1A8H4",
  "channel_name": "#claude-term",
  "poll_interval_seconds": 60,
  "keyword": "@claude",
  "jira_auto_transition": true,
  "default_project_dir": "/home/vm/penops-ui"
}
EOF
```

Update `channel_id` and `default_project_dir` for your environment.

### 4. Initialize registry

```bash
echo '{}' > ~/.claude/slack-ops/registry.json
```

### 5. Set up health check cron

```bash
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/vm/.local/bin/claude-ops-health") | crontab -
```

### 6. First run (one-time workspace trust)

```bash
claude-ops-start
tmux attach -t claude-ops
```

On first launch, Claude will ask to trust `~/.claude/slack-ops` — accept once. This is cached and never asked again.

## Usage

### Start the orchestrator

```bash
claude-ops-start
```

Idempotent — safe to run if already running.

### Dispatch a task from Slack

Post in `#claude-term`:
```
@claude INFRA-1234 fix the login validation bug
```

Optional custom session name:
```
@claude INFRA-1234 [login-fix] fix the login validation bug
```

### Dispatch a task from terminal

```
/slack-task INFRA-1234 fix the login validation bug
```

This posts to `#claude-term` — the orchestrator picks it up on the next poll cycle.

### Interact with a worker

**From Slack**: reply in the task's thread. The orchestrator routes your message to the worker on the next poll (~60s).

**From terminal**: attach directly to the tmux session:
```bash
tmux attach -t INFRA-1234
```

Both inputs work — the worker maintains full context across all interactions.

### Close a session

**From Slack**: reply `@claude close` in the thread.

**From terminal**: attach to the session and type `/exit` or press `Ctrl+C`.

### Check status

```bash
# List all tmux sessions
tmux list-sessions

# View registry
cat ~/.claude/slack-ops/registry.json

# Attach to orchestrator
tmux attach -t claude-ops
```

## Files

### Dot-files (version controlled, stowed)

| File | Package | Description |
|------|---------|-------------|
| `claude/.claude/agents/slack-orchestrator.md` | claude | Orchestrator agent definition |
| `claude/.claude/skills/slack-task/SKILL.md` | claude | Terminal entry point skill |
| `claude/.claude/docs/slack-ops.md` | claude | This README |
| `bin/.local/bin/claude-ops-start` | bin | Start script (idempotent) |
| `bin/.local/bin/claude-ops-health` | bin | Health check for cron |

### Runtime (not version controlled)

| File | Description |
|------|-------------|
| `~/.claude/slack-ops/config.json` | Channel, poll interval, keyword, project dir |
| `~/.claude/slack-ops/registry.json` | Active session state (Jira ID → tmux + thread) |
| `~/.claude/slack-ops/health.log` | Health check restart log |

## How It Works

### Poll Cycle (every ~60s)

1. Read `#claude-term` for new `@claude` messages
2. For each new task: acknowledge in thread, create worktree, spawn tmux session, send initial prompt, transition Jira to "In Progress"
3. For each active session: read thread for new user replies, route to worker via `tmux send-keys`
4. Housekeeping: verify tmux sessions alive, update registry

### Worker Sessions

- Real Claude CLI sessions with `--dangerously-skip-permissions`
- Each gets its own git worktree under `/home/vm/worktrees/<JIRA-ID>`
- Posts directly to their Slack thread via `slack_send_message`
- Full context retained — follow-up messages, redirections, and review iterations all work
- Worker knows its thread_ts and channel_id from the initial prompt

### Message Routing

- **Slack → Worker**: orchestrator reads thread, sends via `tmux send-keys` with Slack context prefix so worker knows to reply to thread
- **Worker → Slack**: worker calls `slack_send_message` directly with `thread_ts`
- **Terminal → Worker**: user attaches via `tmux attach -t <session>`
- **Self-message filtering**: orchestrator skips messages with "Sent using Claude" footer to avoid routing worker messages back to themselves

## Assumptions

- Single user, single machine — no multi-user or distributed setup
- All projects are under `/home/vm/` and worktrees under `/home/vm/worktrees/`
- Jira project key is `INFRA` (configurable per task)
- Slack MCP authenticates as the user — messages appear as "Sent using <user>" (no push notifications for self-sent messages)
- Worker sessions persist until explicitly closed — no auto-timeout
- No concurrency limits — machine resources are the natural constraint
- The orchestrator runs in `~/.claude/slack-ops` as its working directory

## Known Limitations

1. **No push notifications**: Slack MCP posts as your account, so you don't get mobile notifications for worker responses. Workaround: set up a Slack incoming webhook for a different sender identity.
2. **~60s latency**: polling-based, not real-time. Thread replies take up to 60s to reach the worker.
3. **Orchestrator context pressure**: the orchestrator accumulates history over time. May need periodic restart for long-running deployments.
4. **First-run trust prompt**: workspace trust dialog appears once per new directory. Cached after first approval.
5. **Slack message limit**: messages over 4000 chars get truncated. Long worker outputs may need splitting.

## Troubleshooting

**Orchestrator not picking up tasks**:
- Check if tmux session is alive: `tmux has-session -t claude-ops`
- Check orchestrator output: `tmux attach -t claude-ops`
- Verify Slack MCP is authenticated: try `slack_read_channel` manually

**Worker not responding**:
- Check tmux session: `tmux has-session -t INFRA-1234`
- Attach and check: `tmux attach -t INFRA-1234`
- Check registry: `cat ~/.claude/slack-ops/registry.json`

**Permission prompts appearing**:
- Ensure `skipDangerousModePermissionPrompt: true` in settings.json
- Ensure `Bash(tmux *)` and `mcp__plugin_agentq_slack__*` are in the allow list
- The orchestrator uses Bash (not Write tool) for registry updates to avoid file write prompts

**Health check not restarting**:
- Verify cron: `crontab -l | grep claude-ops`
- Check log: `cat ~/.claude/slack-ops/health.log`
