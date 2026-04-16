---
name: slack-task
description: Post a task to #claude-term for the slack-ops orchestrator to pick up. Creates a Slack message that spawns a Claude session in a tmux window. Use when starting a task from the terminal that should be tracked in Slack.
argument-hint: "[session-name] [JIRA-ID] <task description>"
disable-model-invocation: true
---

# Slack Task

Post a task to `#claude-term` for the slack-ops orchestrator to pick up and spawn a worker session.

## Usage

```
/slack-task [login-fix] INFRA-1234 fix the login validation bug
/slack-task [jira-check] check my pending jiras
/slack-task INFRA-1234 fix the login validation bug
/slack-task check my pending jiras
```

- `[name]` in brackets sets the tmux session name (optional)
- Jira ID is optional — without it, no worktree is created
- If no `[name]` and Jira ID is present, session is named after the Jira ID

## Steps

1. **Parse arguments**: extract optional `[session-name]` in brackets, optional Jira ID, and task description
2. **Post to Slack**: send a message to `#claude-term` (channel ID: `C0ASZC1A8H4`):
   ```
   @claude [session-name] JIRA-ID task description
   ```
   Use: `slack_send_message(channel_id="C0ASZC1A8H4", message="@claude ...")`
3. **Return the message link** so the user can follow the thread in Slack
4. **Inform the user**: "Task posted. The orchestrator will pick it up on the next poll cycle (~60s). Thread: <link>"
