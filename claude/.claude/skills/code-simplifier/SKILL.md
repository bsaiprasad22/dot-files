# Code Simplifier

Analyze a project for over-engineered, convoluted, or unnecessarily complex code and suggest simplifications.

## Usage

```
/code-simplify [options]
```

### Options

- `--auto-fix` - Automatically apply fixes without confirmation
- `--path=<dir>` - Target specific directory (default: current project root)
- `--severity=<level>` - Minimum severity to report: `low`, `medium`, `high` (default: `medium`)
- `--dry-run` - Show what would be simplified without making changes

## Instructions

### 1. Project Analysis

First, detect the project type and primary language:

```bash
# Check for language indicators
ls -la package.json tsconfig.json pyproject.toml setup.py Cargo.toml go.mod pom.xml build.gradle *.csproj 2>/dev/null

# Get project structure
find . -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" 2>/dev/null | head -50

# Count files by extension to determine primary language
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn
```

### 2. Over-Engineering Patterns to Detect

Scan the codebase for these anti-patterns:

#### A. Unnecessary Abstraction (High Severity)

```
Pattern: Single-implementation interfaces/abstract classes
- Interface with only one implementing class
- Abstract class with single child
- Factory that creates only one type
- Wrapper class that just delegates to inner object

Fix: Remove abstraction layer, use concrete implementation directly
```

#### B. Premature Generalization (High Severity)

```
Pattern: Generic solutions for specific problems
- Type parameters used in only one way
- Config objects with single usage
- Plugin systems with one plugin
- Strategy pattern with one strategy
- Dependency injection for non-swappable dependencies

Fix: Inline the specific implementation, remove unused flexibility
```

#### C. Over-Defensive Code (Medium Severity)

```
Pattern: Excessive validation/error handling
- Null checks for values that can never be null
- Try-catch around code that can't throw
- Validation of internal/trusted data
- Redundant type assertions
- Multiple layers checking the same condition

Fix: Remove redundant checks, trust internal code paths
```

#### D. Unnecessary Indirection (Medium Severity)

```
Pattern: Code that just passes through
- Functions that only call one other function
- Variables used only once immediately after assignment
- Re-exports without modification
- Middleware/hooks that don't transform data
- Event handlers that just call another function

Fix: Inline the indirection, call directly
```

#### E. Dead/Redundant Code (Medium Severity)

```
Pattern: Code that serves no purpose
- Unused imports, variables, functions, classes
- Commented-out code blocks
- Unreachable code paths
- Duplicate implementations
- Empty error handlers (catch {})
- Console.log/print statements left in

Fix: Remove dead code entirely
```

#### F. Complex Conditionals (Low Severity)

```
Pattern: Hard-to-follow logic
- Deeply nested if/else (>3 levels)
- Long boolean expressions
- Switch with many cases that could be a map
- Negated conditions that could be positive
- Complex ternaries

Fix: Extract to well-named functions, use early returns, simplify logic
```

#### G. Verbose Patterns (Low Severity)

```
Pattern: More code than necessary
- Manual loops that could be map/filter/reduce
- Explicit null coalescing vs ?? operator
- Verbose object construction vs spread
- Callback hell vs async/await
- String concatenation vs template literals

Fix: Use modern language features
```

#### H. Backwards Compatibility Cruft (Medium Severity)

```
Pattern: Compatibility code no longer needed
- Polyfills for supported features
- Renamed variables prefixed with _
- Re-exported types "for backwards compatibility"
- Deprecated function wrappers
- Feature flags that are always on/off

Fix: Remove compatibility shims, clean up exports
```

### 3. Analysis Process

For each source file:

1. **Read the file** using the Read tool
2. **Identify patterns** matching the categories above
3. **Assess severity** based on:
   - How much complexity it adds
   - How often the pattern appears
   - Impact on maintainability
4. **Generate fix** with before/after code
5. **Track location** with file:line reference

### 4. Report Format

Present findings organized by severity:

```markdown
## Code Simplification Report

**Project:** /path/to/project
**Language:** TypeScript
**Files Analyzed:** 45
**Issues Found:** 12

---

### High Severity (3 issues)

#### 1. Unnecessary Abstraction
**File:** `src/services/UserServiceInterface.ts:1`
**Pattern:** Interface with single implementation

**Current Code:**
```typescript
// UserServiceInterface.ts
export interface IUserService {
  getUser(id: string): Promise<User>;
}

// UserService.ts
export class UserService implements IUserService {
  getUser(id: string): Promise<User> { ... }
}

// usage.ts
const service: IUserService = new UserService();
```

**Simplified:**
```typescript
// UserService.ts
export class UserService {
  getUser(id: string): Promise<User> { ... }
}

// usage.ts
const service = new UserService();
```

**Files to delete:** `src/services/UserServiceInterface.ts`

[ ] Apply this fix?

---

#### 2. Premature Generalization
**File:** `src/utils/createHandler.ts:5`
**Pattern:** Factory function used once

...

---

### Medium Severity (6 issues)
...

### Low Severity (3 issues)
...

---

## Summary

| Severity | Count | Est. Lines Removed |
|----------|-------|-------------------|
| High     | 3     | ~120              |
| Medium   | 6     | ~85               |
| Low      | 3     | ~30               |

**Total simplification:** ~235 lines of unnecessary code

---

## Actions

Choose an option:
1. Apply all high severity fixes
2. Apply all fixes
3. Review each fix individually
4. Export report and exit
```

### 5. Fix Application

When applying fixes:

1. **Show the change** clearly with before/after
2. **Ask for confirmation** (unless `--auto-fix`)
3. **Apply using Edit tool** for modifications
4. **Delete files** if entire file is unnecessary
5. **Track changes** for final summary
6. **Run project checks** after all fixes:
   ```bash
   # Verify no syntax errors
   npm run build 2>&1 | head -20  # or equivalent for language

   # Run tests if available
   npm test 2>&1 | tail -20  # or equivalent
   ```

### 6. User Confirmation Flow

For each fix (unless `--auto-fix`):

```
Apply fix #1: Remove IUserService interface?
[y] Yes  [n] No  [a] Apply all remaining  [s] Skip all remaining  [q] Quit
>
```

### 7. Language-Specific Considerations

#### TypeScript/JavaScript
- Check for `any` types that could be specific
- Look for callback patterns vs async/await
- Find unused dependencies in package.json

#### Python
- Check for overly complex class hierarchies
- Find unused imports (use AST or simple grep)
- Look for Java-style patterns (getters/setters for simple attrs)

#### Go
- Check for unnecessary interface definitions
- Find error handling that shadows errors
- Look for over-use of generics

#### Rust
- Check for unnecessary Box/Arc/Rc wrappers
- Find overly complex lifetime annotations
- Look for trait implementations used once

### 8. Exclusions

Skip analysis of:
- `node_modules/`, `vendor/`, `venv/`, `.venv/`
- Build output: `dist/`, `build/`, `target/`, `out/`
- Generated files: `*.generated.*`, `*.g.*`
- Config files: `*.config.js`, `*.config.ts`
- Lock files: `package-lock.json`, `yarn.lock`, `Cargo.lock`
- Test fixtures/snapshots
- Files matching `.gitignore` patterns

### 9. Final Summary

After all fixes applied:

```markdown
## Simplification Complete

**Changes Made:**
- Removed 3 unnecessary interfaces
- Inlined 5 wrapper functions
- Deleted 2 unused utility files
- Simplified 4 complex conditionals

**Files Modified:** 12
**Files Deleted:** 2
**Lines Removed:** 187

**Build Status:** ✓ Passing
**Tests:** ✓ 45/45 passing

The codebase is now simpler and more maintainable.
```

## Error Handling

- If build fails after changes: Offer to revert last change
- If tests fail: Show which tests, offer to revert
- If file can't be parsed: Skip with warning, continue analysis
- If uncertain about fix: Mark as "needs review" instead of auto-fixing
