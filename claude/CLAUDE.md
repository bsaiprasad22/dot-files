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

## Jira Integration

- **Commit messages**: Always include the Jira ID at the start of commit messages (e.g., `PROJ-1234: Fix login validation bug`)
- **Status updates**: Move the ticket to "In Progress" when starting work on a task
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

### Structure Requirements

Every plan must include:
1. **Problem Statement** - Clear definition of what we're solving and WHY
2. **Design Decisions** - Each decision must cite the principle it follows
3. **Implementation Steps** - Concrete, actionable steps
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

### Anti-Patterns to Avoid

- Over-abstraction: Don't create interfaces for single implementations
- Premature optimization: Profile first, optimize second
- Gold-plating: Build what's needed, not what's "cool"
- Cargo-culting: Don't copy patterns without understanding why

