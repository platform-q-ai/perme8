# Quick Start Example

```
User: "Add user profile avatar upload"

Main agent: "I'll orchestrate this feature:

Planning Phases:

  Planning Phase 1 (Optional): First, let me use the prd subagent to gather requirements...
    [Delegates to prd - can skip if requirements are clear]

  Planning Phase 2 (Optional): The architect subagent will create a comprehensive plan...
    [Delegates to architect]
    Output:
    - Detailed implementation plan
    - TodoList.md created with all checkboxes for 3 implementation steps + 2 QA phases

BDD Implementation:
(All agents read TodoList.md and check off items as they complete them)

  Step 1: Create Feature File (RED)
    Output:
    - test/features/user_avatar_upload.feature created
    - Step definitions created
    - Tests run and FAIL (expected - RED state)

  Step 2: Implement Feature via TDD (RED, GREEN)
    [Delegates to phoenix-tdd for backend]
    Output: Backend implemented, unit tests pass

    [Delegates to typescript-tdd for frontend if needed]
    Output: Frontend implemented, unit tests pass

  Main Agent Pre-commit Checkpoint (After Step 2):
    [Main Agent runs: mix precommit]
    [Main Agent runs: npm test]
    [Fixes any issues: formatting, Credo, Dialyzer, TypeScript, tests, boundaries]
    Output: "All pre-commit checks passing. Full test suite green. Ready for Step 3."

  Step 3: Feature Tests Pass (GREEN)
    Output: All feature scenarios pass - full-stack integration verified

Feature complete with full-stack verification!"
```