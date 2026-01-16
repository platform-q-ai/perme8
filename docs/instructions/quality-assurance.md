# Quality Assurance Phases

After implementation is complete, run these quality assurance phases:

## QA Phase 1: Test Validation (Use `@test-validator` subagent)

**When to delegate:**

- After all 4 implementation phases complete
- Before code review
- To verify TDD process was followed across all layers

**What test-validator does:**

- Validates TDD process (tests written first)
- Checks test quality and organization
- Verifies test speed (domain tests in milliseconds)
- Validates test coverage across all layers
- Identifies test smells
- Ensures proper mocking strategy

**Invocation:**

```
"Use the @test-validator subagent to validate the test suite"
```

**Output:** Test validation report with issues and recommendations

## QA Phase 2: Code Review (Use `@code-reviewer` subagent)

**When to delegate:**

- After test validation passes
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