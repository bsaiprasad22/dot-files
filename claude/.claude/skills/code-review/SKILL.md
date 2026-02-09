# Code Review

Review staged changes for issues and provide a summary.

## Instructions

1. Get the staged changes using `git diff --cached`
2. Analyze the changes for issues in the following priority order:
   - **Bugs**: Logic errors, null/undefined issues, edge cases, incorrect behavior
   - **Security**: Vulnerabilities, injection risks, exposed secrets, unsafe operations
   - **Performance**: Inefficient algorithms, memory leaks, unnecessary operations
   - **Best Practices**: Design patterns, error handling, maintainability
   - **Style**: Naming conventions, formatting, code organization

3. Provide a summary organized by category with:
   - File and line references (e.g., `src/auth.js:42`)
   - Description of the issue
   - Severity (Critical, High, Medium, Low)
   - Suggested fix

4. After presenting the summary, ask the user if they want to apply any fixes
5. Only apply fixes with explicit user permission

## Output Format

```
## Code Review Summary

### Bugs
- [Severity] `file:line` - Description
  - Suggested fix: ...

### Security
- ...

### Performance
- ...

### Best Practices
- ...

### Style
- ...

## Verdict
[PASS / PASS WITH WARNINGS / NEEDS FIXES]

Would you like me to apply any of these fixes?
```

## When to Skip Categories

If no issues are found in a category, omit that section from the output.
