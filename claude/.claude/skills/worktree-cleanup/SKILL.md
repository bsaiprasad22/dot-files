# Worktree Cleanup

Automatically clean up git worktrees whose associated Jira tickets have been closed.

## Purpose

Over time, worktrees accumulate for completed work. This skill:
- Scans `/home/vm/worktrees` for worktrees named by Jira ID
- Checks each ticket's status via Jira MCP
- Removes worktrees for closed/done tickets
- Optionally archives or preserves specific worktrees

## Usage

```
/cleanup-worktrees [options]
```

### Options

- `--dry-run` - Show what would be cleaned up without removing anything
- `--force` - Skip confirmation prompts
- `--archive` - Archive to `/home/vm/worktrees/.archive/` instead of deleting
- `--include-merged` - Also check if branches are merged to main (extra safety)
- `--keep=<JIRA-ID>` - Exclude specific worktree from cleanup (can repeat)

## Instructions

### 1. Scan Worktrees

```bash
# List all worktrees in the standard location
ls -la /home/vm/worktrees/

# Get list of worktree directories that match Jira ID pattern
find /home/vm/worktrees -maxdepth 1 -type d -name "[A-Z]*-[0-9]*" | sort
```

### 2. Extract Jira IDs

For each worktree directory:

```bash
# Example: /home/vm/worktrees/INFRA-1234 → INFRA-1234
JIRA_ID=$(basename "/home/vm/worktrees/INFRA-1234")
```

### 3. Check Jira Status

Use Jira MCP to get ticket status:

```
For each JIRA_ID:
1. Call jira_get_issue with the Jira ID
2. Extract the status field
3. Determine if status indicates completion
```

**Closed Statuses** (case-insensitive):
- `Done`
- `Closed`
- `Resolved`
- `Complete`
- `Completed`
- `Won't Do`
- `Cancelled`
- `Rejected`

### 4. Optional: Check Merge Status

If `--include-merged` flag:

```bash
cd /home/vm/worktrees/INFRA-1234

# Check if branch is merged to main/master
git fetch origin
MERGED=$(git branch -r --merged origin/main | grep -E "origin/INFRA-1234$" || true)

if [[ -n "$MERGED" ]]; then
  echo "Branch is merged to main"
fi
```

### 5. Generate Report

```markdown
## Worktree Cleanup Report

**Scanned:** /home/vm/worktrees
**Total Worktrees:** 12
**Candidates for Cleanup:** 5

### Ready for Cleanup (Jira Closed)

| Worktree | Jira ID | Status | Last Modified | Size |
|----------|---------|--------|---------------|------|
| /home/vm/worktrees/INFRA-1234 | INFRA-1234 | Done | 2024-01-10 | 45 MB |
| /home/vm/worktrees/INFRA-1235 | INFRA-1235 | Closed | 2024-01-08 | 32 MB |
| /home/vm/worktrees/PROJ-5678 | PROJ-5678 | Resolved | 2024-01-05 | 28 MB |

**Total Space to Reclaim:** ~105 MB

### Kept (Jira Still Open)

| Worktree | Jira ID | Status |
|----------|---------|--------|
| /home/vm/worktrees/INFRA-1240 | INFRA-1240 | In Progress |
| /home/vm/worktrees/INFRA-1241 | INFRA-1241 | To Do |

### Errors (Could Not Check)

| Worktree | Jira ID | Error |
|----------|---------|-------|
| /home/vm/worktrees/UNKNOWN-999 | UNKNOWN-999 | Ticket not found |

---

Proceed with cleanup? [y/n/s(elect)]
```

### 6. User Confirmation

```
Options:
[y] Yes - clean up all candidates
[n] No - abort
[s] Select - choose which to clean up
[a] Archive - move to archive instead of deleting
[d] Dry-run details - show exact commands that would run
```

If user selects `s`:
```
Select worktrees to clean up (space-separated numbers, or 'all'):

1. [ ] INFRA-1234 (Done)
2. [ ] INFRA-1235 (Closed)
3. [ ] PROJ-5678 (Resolved)

Enter selection: 1 3
```

### 7. Cleanup Execution

For each worktree to clean:

```bash
WORKTREE_PATH="/home/vm/worktrees/INFRA-1234"
JIRA_ID="INFRA-1234"

# Option A: Delete
# First, remove the git worktree reference
cd [main-repo-path]
git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true

# If worktree remove fails (orphaned directory), just delete
if [[ -d "$WORKTREE_PATH" ]]; then
  rm -rf "$WORKTREE_PATH"
fi

# Option B: Archive (if --archive flag)
ARCHIVE_DIR="/home/vm/worktrees/.archive"
mkdir -p "$ARCHIVE_DIR"
mv "$WORKTREE_PATH" "$ARCHIVE_DIR/${JIRA_ID}_$(date +%Y%m%d)"
```

### 8. Also Clean Up Related Artifacts

```bash
# Remove associated plan file
PLAN_FILE="$HOME/.claude/plans/${JIRA_ID}.md"
if [[ -f "$PLAN_FILE" ]]; then
  if [[ "$ARCHIVE" == "true" ]]; then
    mv "$PLAN_FILE" "$ARCHIVE_DIR/${JIRA_ID}_plan.md"
  else
    rm "$PLAN_FILE"
  fi
  echo "Removed plan: $PLAN_FILE"
fi
```

### 9. Post-Cleanup Summary

```markdown
## Cleanup Complete

**Removed:** 3 worktrees
**Space Reclaimed:** ~105 MB
**Plans Removed:** 2

### Cleaned Up
- ✓ INFRA-1234 (Done)
- ✓ INFRA-1235 (Closed)
- ✓ PROJ-5678 (Resolved)

### Remaining Worktrees
- INFRA-1240 (In Progress)
- INFRA-1241 (To Do)

---

Next cleanup: Run `/cleanup-worktrees` again when more tickets are closed.
```

---

## Safety Features

### Pre-Cleanup Checks

Before removing any worktree:

1. **Unpushed commits check:**
   ```bash
   cd "$WORKTREE_PATH"
   UNPUSHED=$(git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null | wc -l)
   if [[ "$UNPUSHED" -gt 0 ]]; then
     echo "WARNING: $JIRA_ID has $UNPUSHED unpushed commits!"
   fi
   ```

2. **Uncommitted changes check:**
   ```bash
   cd "$WORKTREE_PATH"
   if [[ -n $(git status --porcelain) ]]; then
     echo "WARNING: $JIRA_ID has uncommitted changes!"
   fi
   ```

3. **Stash check:**
   ```bash
   cd "$WORKTREE_PATH"
   STASHES=$(git stash list | wc -l)
   if [[ "$STASHES" -gt 0 ]]; then
     echo "WARNING: $JIRA_ID has $STASHES stashed changes!"
   fi
   ```

### Warning Output

```markdown
### ⚠️ Warnings

The following worktrees have potential issues:

| Worktree | Issue | Details |
|----------|-------|---------|
| INFRA-1234 | Unpushed commits | 3 commits not pushed |
| PROJ-5678 | Uncommitted changes | 2 modified files |

These will NOT be cleaned up unless you use --force.
Resolve issues manually or use --force to override.
```

---

## Error Handling

- **Jira MCP unavailable:** Report error, skip status check, keep worktree
- **Ticket not found:** Mark as "unknown status", don't remove unless --force
- **Permission denied:** Report error, continue with others
- **Worktree in use:** Skip with warning (e.g., if it's the current directory)

---

## Scheduling Suggestion

Add to crontab or run periodically:
```bash
# Weekly cleanup check (dry-run)
0 9 * * 1 claude -c "/cleanup-worktrees --dry-run" 2>&1 | mail -s "Worktree Cleanup Report" user@example.com
```
