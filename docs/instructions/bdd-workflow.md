# BDD Implementation Workflow

The BDD workflow creates a feature file first, then implements the feature to make it pass. This provides executable documentation and verifies full-stack integration.

## Implementation Step 1: Create Feature File (RED)

**When to delegate:**

- After requirements are gathered (PRD created)
- Before implementing the feature
- When you want executable specifications

**What fullstack-bdd does in Step 1:**

- Reads the PRD (or requirements from user)
- Creates `.feature` file in `test/features/` with Gherkin scenarios
- Writes step definitions in `test/features/step_definitions/`
- Step definitions contain full-stack test logic (HTTP → HTML)
- Runs tests to verify they FAIL (RED state)
- Documents expected behavior in business language

**Invocation:**

```
"Use the @fullstack-bdd subagent to create feature file and step definitions from the PRD"
```

**Output:**

- `.feature` file with Gherkin scenarios (Given/When/Then)
- Step definitions implementing full-stack test logic
- Tests run and FAIL (expected - feature not implemented yet)
- Clear specification of what needs to be built

**Example Feature File Created:**

```gherkin
Feature: Document Visibility Management
  As a document owner
  I want to control document visibility
  So that I can share documents with my team or keep them private

  Background:
    Given a workspace exists with name "Product Team" and slug "product-team"
    And the following users exist:
      | Email              | Role   |
      | alice@example.com  | Owner  |
      | bob@example.com    | Member |

  Scenario: Owner makes document public
    Given I am logged in as "alice@example.com"
    And a document "Product Roadmap" exists owned by "alice@example.com"
    When I make the document public
    Then the document visibility should be "public"
    And "bob@example.com" should be able to view the document

  Scenario: Member cannot change document visibility
    Given I am logged in as "bob@example.com"
    And a document "Product Roadmap" exists owned by "alice@example.com"
    When I attempt to make the document public
    Then I should receive a forbidden error
```

---

## Implementation Step 2: Implement Feature via TDD (RED, GREEN)

**After feature file is created (Step 1), implement the feature using TDD agents:**

**For Backend Implementation:**

```
"Use the @phoenix-tdd subagent to implement backend for document visibility feature"
```

Phoenix-tdd implements:

- Domain logic (pure functions, visibility rules)
- Application layer (use cases with authorization)
- Infrastructure (database, queries)
- Interface (LiveView, controllers)

Each component follows RED-GREEN-REFACTOR cycle at unit level.

**For Frontend Implementation (if needed):**

```
"Use the @typescript-tdd subagent to implement frontend for document visibility UI"
```

Typescript-tdd implements:

- Domain logic (client-side validation)
- Application layer (visibility update use cases)
- Infrastructure (API calls, storage)
- Presentation (LiveView hooks, UI updates)

Each component follows RED-GREEN-REFACTOR cycle at unit level.

**During Step 2:**

- Unit tests pass (GREEN at unit level)
- Feature tests may still fail (RED at integration level)
- This is expected - implementation is incremental

**Main Agent Action During Implementation:**

Run pre-commit checks periodically to catch issues early:

```bash
mix precommit
```

Fix any issues:

- If formatter changes code: Review and commit changes
- If Credo reports warnings: Fix issues
- If Dialyzer reports type errors: Fix type specs
- If tests fail: Debug and fix failing tests
- If boundary violations: Refactor to fix violations

---

## Implementation Step 3: Feature Tests Pass (GREEN)

**When all units are implemented:**

```
"Use the @fullstack-bdd subagent to verify feature tests pass"
```

**What fullstack-bdd does in Step 3:**

- Runs all feature scenarios
- Verifies full-stack integration (HTTP → HTML)
- All scenarios pass (GREEN state)
- Feature is complete and verified end-to-end

**Invocation:**

```
"Use the @fullstack-bdd subagent to run feature tests and verify they pass"
```

**Output:**

- All feature scenarios pass
- Full-stack integration verified
- Executable documentation of feature behavior

---

## BDD Testing Principles

The fullstack-bdd agent follows strict principles:

1. **Full-Stack Testing** - Always test HTTP → HTML, never backend-only
2. **Real Database** - Use Ecto Sandbox, not mocked repositories
3. **Mock 3rd Parties** - Mock external APIs (LLMs, payments, etc.)
4. **LiveViewTest First** - Use Phoenix.LiveViewTest, only Wallaby for `@javascript`
5. **Business Language** - Write tests in Gherkin (Given/When/Then)
6. **Executable Docs** - Tests document feature behavior