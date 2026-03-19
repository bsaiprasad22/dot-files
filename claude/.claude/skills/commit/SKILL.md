---
name: commit
description: Generate structured git commits with Jira ticket references and conventional commit format. Use when committing staged changes, creating git commits, or preparing commit messages.
argument-hint: "[--amend] [--scope=<scope>] [--type=<type>] [--dry-run]"
disable-model-invocation: true
---

# Git Commit

Generate brief, complete, and properly structured git commits with Jira ticket references.

## Usage

```
/commit [options]
```

### Options

- `--amend` - Amend the previous commit (use cautiously)
- `--scope=<scope>` - Override auto-detected scope
- `--type=<type>` - Override auto-detected type
- `--dry-run` - Show commit message without committing

## Pre-loaded Context

**Current branch:** !`git branch --show-current 2>/dev/null`
**Staged files:** !`git diff --cached --name-only 2>/dev/null`
**Staged stats:** !`git diff --cached --stat 2>/dev/null`
**Recent commits (style reference):** !`git log --oneline -5 2>/dev/null`

## Instructions

### 1. Gather Context

Use the pre-loaded context above. If more detail is needed:

```bash
# Get detailed diff for analysis
git diff --cached
```

### 2. Analyze Changes

Examine the staged changes to determine:

```
Analysis Checklist:
- What files changed? (new, modified, deleted)
- What type of change? (feature, fix, refactor, test, docs, chore)
- What component/scope? (api, ui, auth, db, etc.)
- What is the primary intent?
- Are there breaking changes?
```

### 3. Commit Message Format

Follow Conventional Commits with Jira ID prefix:

```
<JIRA-ID>: <type>(<scope>): <subject>

[optional body]

[optional footer]
```

#### Components

**Jira ID:** From branch name (e.g., `INFRA-1234`)

**Type:** (auto-detect from changes)
| Type | When to Use | File Patterns |
|------|-------------|---------------|
| `feat` | New feature/capability | New files, new exports, new endpoints |
| `fix` | Bug fix | Changes to existing logic, error handling |
| `refactor` | Code restructuring | Renames, reorganization, no behavior change |
| `test` | Test changes only | `*.test.*`, `*.spec.*`, `__tests__/*` |
| `docs` | Documentation only | `*.md`, `docs/*`, comments only |
| `chore` | Build/config/tooling | `package.json`, configs, CI files |
| `perf` | Performance improvement | Optimization, caching, query improvements |
| `style` | Formatting only | Whitespace, semicolons, no logic change |

**Scope:** (auto-detect from file paths)
| Files Changed | Suggested Scope |
|---------------|-----------------|
| `src/api/*`, `src/routes/*` | `api` |
| `src/components/*`, `src/pages/*` | `ui` |
| `src/auth/*`, `**/auth/**` | `auth` |
| `src/db/*`, `**/models/*` | `db` |
| `src/utils/*`, `src/lib/*` | `utils` |
| `tests/*`, `__tests__/*` | `test` |
| `*.config.*`, `.*rc` | `config` |
| Multiple unrelated areas | omit scope |

**Subject:** (required)
- Imperative mood: "add" not "added" or "adds"
- No period at end
- Max 50 characters (excluding Jira ID prefix)
- Complete the sentence: "This commit will..."

### 4. Subject Line Guidelines

**Good Examples:**
```
INFRA-1234: feat(auth): add OAuth2 login flow
INFRA-1234: fix(api): handle null user in profile endpoint
INFRA-1234: refactor(db): extract query builder to separate module
INFRA-1234: test: add integration tests for payment flow
INFRA-1234: chore: upgrade dependencies to fix vulnerabilities
```

**Bad Examples:**
```
INFRA-1234: fixed bug          # Too vague
INFRA-1234: WIP                # Not descriptive
INFRA-1234: updates            # What updates?
INFRA-1234: feat: Add new feature for users to do things  # Too long, vague
```

### 5. Body Guidelines (Optional)

Add body when:
- Change is not self-explanatory from subject
- There's important context (why, not what)
- There are notable implementation decisions

Format:
```
INFRA-1234: fix(api): handle null user in profile endpoint

The findUser() function returns undefined when user not found,
but the profile handler assumed it always returns a user object.

Added explicit null check with proper 404 response.
```

Rules:
- Blank line between subject and body
- Wrap at 72 characters
- Explain WHY, not WHAT (the diff shows what)
- Use bullet points for multiple items

### 6. Footer Guidelines (Optional)

Add footer for:
- Breaking changes
- Issue references
- Co-authors

```
INFRA-1234: feat(api)!: change authentication to JWT

BREAKING CHANGE: API now requires Bearer token instead of session cookie.
Clients must update authentication headers.

Co-authored-by: Name <email@example.com>
```

### 7. Commit Generation Flow

```markdown
## Staged Changes Analysis

**Files Changed:**
- `src/api/users.ts` (modified)
- `src/api/users.test.ts` (modified)

**Type Detected:** `fix` (changes to existing logic)
**Scope Detected:** `api` (files in src/api/)
**Jira ID:** `INFRA-1234` (from branch)

---

## Generated Commit Message

```
INFRA-1234: fix(api): handle null user in profile endpoint
```

---

Proceed with this commit? [y/n/e(dit)]
```

### 8. User Confirmation

```
Options:
[y] Yes - commit with this message
[n] No - abort
[e] Edit - modify the message
[b] Body - add a body to the message
[v] Verbose - show full diff again
```

### 9. Execute Commit

```bash
# Standard commit
git commit -m "INFRA-1234: fix(api): handle null user in profile endpoint"

# With body (use heredoc for multi-line)
git commit -m "$(cat <<'EOF'
INFRA-1234: fix(api): handle null user in profile endpoint

The findUser() function returns undefined when user not found,
but the profile handler assumed it always returns a user object.

Added explicit null check with proper 404 response.
EOF
)"

# Verify commit
git log -1 --oneline
```

### 10. Post-Commit Output

```markdown
## Commit Created

**Hash:** `a1b2c3d`
**Message:** `INFRA-1234: fix(api): handle null user in profile endpoint`
**Files:** 2 changed, +15, -3

Next steps:
- `git push` to push to remote
- `/jira-update update --time=30m` to log work
```

---

## Special Cases

### No Staged Changes
```
No changes staged for commit.

Options:
1. Stage all changes: git add -A
2. Stage specific files: git add <file>
3. Interactive staging: git add -p
```

### Multiple Unrelated Changes
```
Warning: Staged changes appear to touch unrelated areas:
- src/api/users.ts (api)
- src/components/Button.tsx (ui)
- scripts/deploy.sh (devops)

Consider splitting into separate commits:
1. Commit API changes only
2. Commit UI changes only
3. Commit devops changes only

Proceed anyway? [y/n/s(plit)]
```

### Breaking Changes
```
Detected potential breaking change:
- Removed export: `getUserById`
- Changed function signature: `authenticate()`

Add BREAKING CHANGE footer? [y/n]
```

### Amend Safety
```
Warning: --amend requested

Checks:
- [ ] Last commit is yours (not someone else's)
- [ ] Last commit is not pushed to remote
- [ ] This is intentional modification, not a new commit

Last commit: "INFRA-1234: feat(api): add user endpoint"

Proceed with amend? [y/n]
```

---

## Configuration

Respects these conventions from CLAUDE.md:
- Jira ID prefix in commit messages
- Branch name = Jira ID
- **No watermarks** - Do not add "Generated with Claude Code" or similar
- **No co-author** - Do not add "Co-Authored-By: Claude" attribution
- **Clean commits** - Keep messages focused on actual changes only
