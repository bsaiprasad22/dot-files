# CLAUDE.md - User Configuration

## General Behavior

- Be unassuming - do not make assumptions about requirements or intent
- Always ask clarifying questions before proceeding with a task
- Only skip clarification if the user explicitly says not to ask questions
- When autocompacting, preserve all relevant context - if unsure what to retain, ask the user and present summaries of the context being considered for retention
- **Concision over grammar** - sacrifice proper grammar for brevity in all output: commits, plans, comments, documentation. Short and clear beats grammatically correct

## Testing

- Follow TDD approach: write a failing test first, then implement the fix
- Verify the test fails before fixing to ensure test correctness
- Only then make the test pass with the implementation
- Run tests in a **venv** or **docker container** — never against system Python

## Python Environment

- **Always use venv** for pip installs — never install packages globally
- If a venv already exists in the project (e.g., `venv/`, `.venv/`), activate it
- If no venv exists, create one: `python3 -m venv .venv && source .venv/bin/activate`
- Use `pip install` only inside an active venv or a docker container
- When running Python scripts or tests, ensure the venv is activated first

## Dot-Files & Stow

- **All** skills, commands, subagents, hooks, and generic binaries must live in `~/dot-files` and be symlinked via GNU Stow
- Claude-specific items go in `dot-files/claude/.claude/` (skills, agents, commands, notify.sh, settings.json)
- Generic scripts go in `dot-files/bin/.local/bin/` (targets `~/.local/bin/`)
- Never place new scripts/configs directly in `~/.claude/` or `~/bin/` — always add to dot-files first, then stow
- If unsure whether something belongs in dot-files, ask the user

## Project Setup

When starting any new project, task, or bug fix:

1. **Always create a new git worktree** under `/home/vm/worktrees`
2. **Require a Jira ID** - Ask the user for the Jira ticket ID before proceeding
3. Name the worktree directory using the Jira ID (e.g., `/home/vm/worktrees/PROJ-1234`)

### penops-ui Workspace Setup

When working on penops-ui projects, use these commands to set up the worktree:

```bash
# Create worktree from main branch
cd /home/vm/penops-ui
git worktree add /home/vm/worktrees/<JIRA-ID> -b <JIRA-ID> main

# Install dependencies (legacy-peer-deps required due to dependency conflicts)
cd /home/vm/worktrees/<JIRA-ID>
npm install --legacy-peer-deps
```

**Important:** Always use `--legacy-peer-deps` flag when running npm install for penops-ui projects.

## Hobby Project Mode

Activated when the user says "hobby project". Overrides work-specific defaults:

- **No Jira** — skip ticket ID, status updates, session summaries, Jira ID in commits
- **No worktrees** — work directly in the repo
- **Remote** — push to `git@github.com:bsaiprasad22/<repo-name>.git` (origin, not a separate private remote)
- **Commits** — plain descriptive messages (no Jira prefix, still no watermarks/co-author)
- **Plans** — still saved to `~/.claude/plans/` for cross-session access, named `<project-name>.md` (ask user for a short name if unclear)

Everything else (TDD, dot-files/stow, design principles, plan structure, architect workflow) still applies.

## MCP Server Preferences

- **Jira**: Always use `pensando_jira` MCP server (`mcp__pensando_jira__*` tools)
- **Confluence**: Always use `cloud_atlassian` MCP server (`mcp__cloud_atlassian__confluence_*` tools)

## Jira Integration

- **Project key**: Always use the `INFRA` project when creating Jira tickets
- **Assignee**: Always assign tickets to Sai Bapa (account ID: `61d0f1c2e763790068d923a0`) unless explicitly told otherwise
- **Commit messages**: Always include the Jira ID at the start of commit messages (e.g., `INFRA-1234: Fix login validation bug`)
- **Status updates**: Move the ticket to "In Progress" when starting work on a task
- **Closing tickets**: When transitioning INFRA tickets to Done, also set the "Outcome" field to "Done"
- **Session summary**: At the end of a task, post a comment to the Jira ticket via MCP that includes:
  - Overall changes made (files added/modified/deleted)
  - Solution summary explaining the approach and fix

## Git Commits

- **No watermarks**: Do not add "Generated with Claude Code" or similar watermarks to commit messages
- **No co-author**: Do not add "Co-Authored-By: Claude" or similar attribution lines
- **Clean commits**: Keep commit messages focused on the actual changes without any AI-related metadata

## Plan Generation Guidelines

When generating implementation plans (in plan mode), follow these principles:

### Plan Storage and Naming

**CRITICAL:** Plans must be saved using the Jira ID as the filename:

```
~/.claude/plans/<JIRA-ID>.md
```

Examples:
- `~/.claude/plans/INFRA-1234.md`
- `~/.claude/plans/PROJ-5678.md`

This enables:
- **Cross-session continuity** - Plan in one session, implement in another
- **Branch-plan association** - Branch name = Jira ID = Plan filename
- **Skill integration** - `/challenge-plan` auto-detects plan from branch

When entering plan mode:
1. Determine the Jira ID (from branch name or ask user)
2. Save plan to `~/.claude/plans/<JIRA-ID>.md`
3. Reference this path when discussing the plan

### Planning Phase Behavior

Plan mode is **elaborate and interactive**. Treat it as a collaborative design session:

- **Solicit user input at every major decision point** — don't just present a plan, discuss it
- **For each implementation step**, cover:
  - Detailed implementation approach (what code, where, how)
  - Corner cases and edge cases — enumerate them explicitly
  - Testing strategy — what tests to write, what they validate, expected inputs/outputs
  - Validation criteria — how we know this step is done and correct
- **Ask clarifying questions** throughout — surface ambiguities early
- **Multiple rounds of feedback** are expected — iterate until the user is satisfied
- **No rushing** — thoroughness in planning saves time in implementation

### Structure Requirements

Every plan must include:
1. **Problem Statement** - Clear definition of what we're solving and WHY
2. **Design Decisions** - Each decision must cite the principle it follows
3. **Implementation Steps** - Concrete, actionable steps with corner cases, testing, and validation for each
4. **Trade-offs** - What we're giving up and why it's acceptable

### Design Principles to Apply

Prioritize maintainability and modularity. For each architectural decision, explicitly state which principle(s) justify it:

**SOLID Principles:**
- **SRP** (Single Responsibility) - One reason to change per component
- **OCP** (Open/Closed) - Extend without modifying
- **LSP** (Liskov Substitution) - Subtypes must be substitutable
- **ISP** (Interface Segregation) - Small, focused interfaces
- **DIP** (Dependency Inversion) - Depend on abstractions

**Simplicity Principles:**
- **KISS** - Prefer simple over clever
- **YAGNI** - Don't build for hypothetical futures
- **DRY** - Single source of truth (but don't over-abstract)

**Modularity Principles:**
- **High Cohesion** - Related things together
- **Low Coupling** - Components change independently
- **Encapsulation** - Hide implementation details
- **Composition > Inheritance** - Favor flexible composition

### Plan Format

```markdown
## Problem Statement
[What problem are we solving and why does it matter?]

## Design Decisions

| Decision | Principle | Rationale |
|----------|-----------|-----------|
| Use service layer | SRP | Separates business logic from controllers |
| No abstract factory | YAGNI | Only one implementation needed |
| Interface for external API | DIP | Allows mocking and future provider changes |

## Implementation Steps
1. [Step with clear outcome]
2. [Step with clear outcome]
...

## Trade-offs
| Choice | Alternative | Why This Choice |
|--------|-------------|-----------------|
| SQL over NoSQL | NoSQL | Relational data, ACID needed, team expertise |
```

### Architect Planning Workflow

When entering plan mode, follow the **three-phase workflow** (detailed in memory: `architect-workflow.md`):

1. **Architect Draft** — explore codebase, draft full plan, save to `~/.claude/plans/<JIRA-ID>.md`
2. **Devil's Advocate Challenge** — launch `devils-advocate` subagent against the plan
   - Focus: over-engineering, missing edge cases. Never compromise security/performance
   - Max 2 rounds. If still contested after round 2, escalate to user — don't loop
   - Update plan with accepted findings, reject with reason in trade-offs table
3. **Simplification Pass** — re-read entire plan, remove anything non-essential
   - Keep: security, performance, boundary error handling
   - Remove: single-use abstractions, "just in case" config, pass-through layers
   - When unsure, ask the user
4. **Append Review Log** to plan showing what changed and why
5. **ExitPlanMode** for user approval

### Anti-Patterns to Avoid

- Over-abstraction: Don't create interfaces for single implementations
- Premature optimization: Profile first, optimize second
- Gold-plating: Build what's needed, not what's "cool"
- Cargo-culting: Don't copy patterns without understanding why

## Autonomous Implementation Mode

Once a plan is approved and implementation begins, **execute autonomously without pausing for user input or permission**. The plan has been discussed and agreed — now just build it.

### Do NOT ask the user for:
- Permission to create/edit/delete files
- Permission to run tests, linters, build commands
- Permission to install dependencies (npm install, pip install, etc.)
- Permission to run scripts that the agent itself wrote
- Confirmation between implementation steps
- "Should I continue?" or "Does this look good?" prompts

### DO stop and ask the user before:
- Running Dockerfiles, docker-compose files, or container commands **not created by the agent in this session**
- Modifying database entries directly (INSERT/UPDATE/DELETE on production or shared DBs)
- Destructive git operations (force push, reset --hard, branch -D on shared branches)
- Deploying to any environment
- Running commands that affect external/shared infrastructure
- Executing scripts from untrusted or unfamiliar sources

### Pre-Commit Code Simplification

After implementation is complete and all tests pass, run `/simplify` on changed files before committing.

**Accept** simplifications that:
- Reduce unnecessary complexity, redundant logic, or verbose patterns
- Improve readability without changing behavior

**Reject** simplifications that:
- Weaken security measures
- Degrade performance
- Contradict design decisions from the approved plan
- Remove error handling at system boundaries

This is distinct from the planning-phase Simplification Pass — that challenges the *design*, this challenges the *code*.

### Guiding principle:
If the action is local, reversible, and scoped to the task — just do it. If it touches shared state, external systems, or is hard to undo — ask first.

