# Jira Update

Intelligent Jira ticket management - create, update, track work, and close tickets based on git branch context.

## Usage

```
/jira-update [action] [options]
```

### Actions

- `start` - Create ticket or move to In Progress, begin tracking
- `update` - Update worklog, description, add sub-tasks
- `complete` - Mark as Done, add final summary
- `sync` - Sync ticket with current branch/PR state
- `status` - Show current ticket status and work summary

### Options

- `--project=<KEY>` - Jira project key (default: INFRA)
- `--time=<duration>` - Time spent (e.g., "2h", "30m", "1h 30m")
- `--message=<text>` - Work description for worklog
- `--pr` - Include PR information in update

## Instructions

### 1. Context Gathering

First, gather context from the current environment:

```bash
# Get current branch (this IS the Jira ID)
git branch --show-current

# Get recent commits on this branch
git log --oneline -10

# Get changed files
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~10...HEAD

# Check for open PRs
gh pr list --head $(git branch --show-current) --json number,title,state,url 2>/dev/null
```

### 2. Determine Jira Ticket

- Branch name IS the Jira ID (e.g., `INFRA-1234`)
- If branch doesn't match pattern `[A-Z]+-[0-9]+`, ask user for Jira ID
- Default project is `INFRA` if only number provided

### 3. Action Handlers

#### START Action

1. Use `jira_get_issue` to check if ticket exists
2. If ticket doesn't exist:
   - Ask user for ticket title and description
   - Use `jira_create_issue` to create it
3. Get available transitions using `jira_get_transitions`
4. Transition to "In Progress" using `jira_transition_issue`
5. Add initial worklog if `--time` provided using `jira_add_worklog`
6. Update ticket description with branch info

#### UPDATE Action

1. Fetch ticket using `jira_get_issue`
2. Analyze git commits since last update to suggest sub-tasks:
   - Group commits by area (frontend, backend, tests, docs, config)
   - Present suggested sub-tasks to user for confirmation
   - Create confirmed sub-tasks using `jira_create_issue` with parent link
3. If `--time` provided:
   - Add worklog entry using `jira_add_worklog`
   - Include commit summary in worklog description
4. Update description with:
   - Files changed summary
   - Key changes from commit messages
   - Current progress status

#### COMPLETE Action

1. Check if PR is merged (if `--pr` flag or PR exists):
   ```bash
   gh pr list --head $(git branch --show-current) --state merged --json number
   ```
2. Generate completion summary:
   - Total files changed
   - Summary of all commits
   - Sub-tasks completed
   - Total time logged
3. Update ticket description with final summary
4. Add final worklog if `--time` provided
5. Get available transitions and move to "Done"
6. Post completion comment with:
   - PR link (if applicable)
   - Final commit hash
   - Change summary

#### SYNC Action

1. Fetch current ticket state
2. Compare with git/PR state:
   - Check if PR is open/merged/closed
   - Check for new commits since last sync
3. Suggest appropriate state transition:
   - PR opened → stay In Progress
   - PR merged → suggest Complete
   - PR closed without merge → ask user
4. Update description with current state
5. Ask user to confirm any state changes

#### STATUS Action

1. Fetch ticket using `jira_get_issue`
2. Get all worklogs using `jira_get_worklogs`
3. Get sub-tasks if any
4. Display:
   - Current status
   - Total time logged
   - Sub-tasks and their status
   - Last update timestamp
   - Associated PR status

### 4. Sub-task Detection Logic

Analyze commits to suggest sub-tasks:

```
Categories:
- "Frontend Changes" - if files match: src/components/*, src/pages/*, *.tsx, *.jsx, *.css, *.scss
- "Backend Changes" - if files match: src/api/*, src/server/*, src/services/*, *.controller.*, *.service.*
- "Database Changes" - if files match: **/migrations/*, **/models/*, *.sql, schema.*
- "Test Updates" - if files match: **/*.test.*, **/*.spec.*, **/tests/*
- "Documentation" - if files match: *.md, docs/*, README*
- "Configuration" - if files match: *.config.*, *.json, *.yaml, *.yml, .env*
- "DevOps/CI" - if files match: .github/*, Dockerfile*, docker-compose*, **/ci/*
```

Present detected categories to user:
```
Based on your changes, I suggest creating these sub-tasks:
1. [x] Frontend Changes (12 files)
2. [x] Backend Changes (5 files)
3. [ ] Test Updates (3 files)

Which sub-tasks should I create? (Enter numbers or 'all'/'none')
```

### 5. State Transition Logic

```
Current State → Trigger → Action
─────────────────────────────────────────────────
Not Found    → start   → Create ticket, move to In Progress
To Do        → start   → Move to In Progress
In Progress  → update  → Stay In Progress, update content
In Progress  → complete→ Move to Done
Done         → *       → Warn user ticket is already closed
```

### 6. Worklog Format

When adding worklog entries:
```
Time: [duration from --time]
Description:
[--message if provided, otherwise auto-generate from commits]

Commits included:
- abc1234: Fix login validation
- def5678: Add error handling
```

### 7. Description Update Format

Append to ticket description:
```markdown
---
## Development Progress

**Branch:** `INFRA-1234`
**Last Updated:** 2024-01-15 14:30 UTC

### Changes Summary
- Modified 15 files (+342, -128 lines)
- Key areas: Authentication, API endpoints

### Recent Commits
- `abc1234` Fix login validation
- `def5678` Add error handling for edge cases

### Sub-tasks
- [x] INFRA-1234-1: Backend Changes
- [ ] INFRA-1234-2: Frontend Changes

### PR Status
- PR #42: Open - "Add user authentication"
```

## Error Handling

- If Jira MCP tools unavailable: Inform user and suggest checking MCP connection
- If ticket not found on update/complete: Offer to create it
- If transition not available: Show available transitions and ask user to choose
- If worklog fails: Continue with other updates, report error at end

## Output Format

Always provide clear feedback:
```
## Jira Update: INFRA-1234

✓ Moved to In Progress
✓ Added worklog: 2h 30m
✓ Created sub-task: INFRA-1235 (Backend Changes)
✓ Updated description with change summary

Current Status: In Progress
Total Time Logged: 4h 30m
Sub-tasks: 1 open, 0 done

Next steps:
- Continue development
- Run `/jira-update update --time=1h` to log more work
- Run `/jira-update complete` when PR is merged
```
