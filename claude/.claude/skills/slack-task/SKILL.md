---
name: slack-task
description: Post a task to #claude-term for the slack-ops orchestrator to pick up. Creates a Slack message that spawns a Claude session in a tmux window. Use when starting a task from the terminal that should be tracked in Slack.
argument-hint: "<JIRA-ID> <task description>"
disable-model-invocation: true
---

# Slack Task

Post a task to `#claude-term` for the slack-ops orchestrator to pick up and spawn a worker session.

## Usage

```
/slack-task INFRA-1234 fix the login validation bug
/slack-task INFRA-1234 [login-fix] fix the login validation bug
```

The optional `[name]` sets the tmux session name (defaults to the Jira ID).

## Steps

1. **Parse arguments**: extract Jira ID, optional session name in brackets, and task description from the args
2. **Validate**: ensure a Jira ID is provided (pattern: `[A-Z]+-[0-9]+`). If missing, ask the user.
3. **Post to Slack**: send a message to `#claude-term` (channel ID: `C0ASZC1A8H4`):
   ```
   @claude <JIRA-ID> [optional-name] <task description>
   ```
   Use: `slack_send_message(channel_id="C0ASZC1A8H4", message="@claude <JIRA-ID> <description>")`
4. **Return the message link** so the user can follow the thread in Slack
5. **Inform the user**: "Task posted. The orchestrator will pick it up on the next poll cycle (~60s). Thread: <link>"
