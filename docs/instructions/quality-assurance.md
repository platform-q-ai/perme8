# Quality Assurance Phases

After implementation is complete, run these quality assurance phases:

## QA Phase 1: Code Review (Use `@code-reviewer` subagent)

**When to delegate:**

- After all implementation phases complete
- Before committing code
- To ensure architectural compliance

**What code-reviewer does:**

- Runs `mix boundary` to check violations
- Reviews SOLID principles compliance
- Checks for security vulnerabilities
- Validates code quality
- Ensures proper error handling
- Verifies PubSub broadcasts after transactions
- Checks performance concerns

**Invocation:**

```
"Use the @code-reviewer subagent to review the implementation"
```

**Output:** Code review report with approval or required changes