# Subagent Coordination

## When to use multiple subagents in sequence:

```
User: "Add real-time notification feature"

Planning Phases:
  Planning Phase 1 (Optional): prd → Gather detailed requirements
  Planning Phase 2 (Optional): architect → Plan implementation

BDD Implementation:
  Step 1: Create .feature file from PRD (RED)
  Step 2: Implement via TDD (RED, GREEN)
    - phoenix-tdd → Backend implementation (domain, application, infrastructure, interface)
    - typescript-tdd → Frontend implementation (domain, application, infrastructure, presentation)
  Step 3: Feature tests pass (GREEN)

```

## Key Points:

- **Feature file first** - Always start with executable specifications
- **Full-stack integration** - Feature tests verify complete user workflows
- **Unit tests support** - TDD agents implement units with their own tests
- **End-to-end verification** - Feature tests confirm everything works together

## When main Agent should handle directly:

- Simple bug fixes (< 5 lines)
- Configuration updates
- Exploratory research
- Answering questions about codebase

## IMPORTANT: When user requests acceptance criteria or feature specifications:

Main Agent should ALWAYS create a `.feature` file in `test/features/` using Gherkin syntax, NOT a markdown document. Even for simple requests, use BDD format:

```gherkin
Feature: [Feature Name]
  As a [user role]
  I want [goal]
  So that [benefit]

  Scenario: [Scenario name]
    Given [precondition]
    When [action]
    Then [expected result]
```

**Examples:**
- User asks: "Create acceptance criteria for checkbox strikethrough"
  → Main Agent creates: `test/features/todo_checkbox_strikethrough.feature`
- User asks: "Write specs for user login"
  → Main Agent creates: `test/features/user_login.feature`

This creates executable specifications from the start.

## Critical Rules

3. **ALWAYS run in sequence** - Each phase depends on previous
4. **NEVER write implementation before tests** - Non-negotiable
5. **Feature file first** - Write .feature before implementation
6. **Full-stack tests** - Always verify HTTP → HTML
7. **Real database** - Use Ecto Sandbox, not mocks
8. **Business language** - Gherkin scenarios readable by non-developers