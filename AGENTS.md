This file provides guidance to OpenCode when working with Elixir and Phoenix code in this repository.

## 🤖 Orchestrated Development Workflow

**This project uses specialized subagents to maintain code quality, architectural integrity, and TDD discipline.**

### Feature Implementation Protocol

When implementing a new feature, follow this orchestrated workflow:

### Planning Phases

#### Planning Phase 1: Requirements Gathering (Use `@prd` subagent) - OPTIONAL

**When to delegate:**

- User has a feature idea but requirements are unclear
- Feature is complex and needs detailed specification

**What the prd agent does:**

- Interviews user with structured questions
- Gathers functional and non-functional requirements
- Researches existing codebase for context
- Documents user stories, workflows, and acceptance criteria
- Identifies constraints, edge cases, and success metrics
- Creates comprehensive Product Requirements Document (PRD)

**Invocation:**

```
"Use the @prd subagent to gather requirements for [feature]"
```

**Output:**

- Comprehensive PRD with user stories, requirements, constraints, and codebase context
- **IMPORTANT**: Main Agent MUST save the PRD to `jargav3/docs/features/[feature-name]-prd.md`

**Note:** You can skip this phase if requirements are already clear and well-defined. Go directly to Planning Phase 2 for simple, well-understood features.

#### Planning Phase 2: Technical Planning (Use `@architect` subagent)

**When to delegate:**

- User requests a new feature
- Feature spans multiple layers or contexts
- Implementation requires TDD planning

**What the architect does:**

- Reads architectural documentation
- Creates comprehensive TDD implementation plan
- Identifies affected boundaries
- Plans RED-GREEN-REFACTOR cycles for each layer
- **Creates TodoList.md file** with all checkboxes for tracking

**Invocation:**

```
"Use the @architect subagent to plan implementation of [feature]"
```

**Output:**

- Detailed implementation plan with test-first steps for all layers
- **IMPORTANT**: Main Agent MUST save the implementation plan to `jargav3/docs/features/[feature-name]-implementation-plan.md`
- **TodoList.md file** in project root with all checkboxes organized by phase

**After Planning Phase 2, Main Agent MUST:**

1. Save the architect's full implementation plan to `docs/features/[feature-name]-implementation-plan.md`
2. Save the prd agent's PRD to `docs/features/[feature-name]-prd.md` (if Planning Phase 1 was run)
3. Update `TodoList.md` header to reference these documents with full file paths
4. Ensure TodoList.md includes note: "IMPORTANT FOR SUBAGENTS: Read both the PRD and Implementation Plan before starting"

**The TodoList.md File:**
The architect creates a `TodoList.md` file that serves as the **single source of truth** for implementation progress. This file:

- Contains ALL implementation checkboxes from the detailed plan
- References PRD and Implementation Plan at the top with full file paths
- Organized by Implementation Phases (1-4) and QA Phases (1-3)
- Uses status indicators: ⏸ (Not Started), ⏳ (In Progress), ✓ (Complete)
- Implementation agents check off items as they complete them
- Main Agent updates phase status between agent runs

### Implementation Phases (From Architect's Plan)

The architect creates a plan with 4 implementation phases. Each phase is executed by the appropriate TDD subagent:

#### Implementation Phase 1: Backend Domain + Application (Use `@phoenix-tdd` subagent)

**When to delegate:**

- Implementing Phase 1 from architect's plan
- Pure business logic and use case orchestration
- No database or UI yet

**What phoenix-tdd does:**

- Reads TodoList.md to understand Phase 1 scope
- Reads the PRD and Implementation Plan referenced in TodoList.md for full context
- Strictly follows RED-GREEN-REFACTOR cycle
- Implements Domain Layer (pure functions, no I/O)
- Implements Application Layer (use cases with mocked dependencies)
- **Checks off items in TodoList.md** as they're completed
- Completes ALL checkboxes in Phase 1
- Does NOT ask "should I continue?" - completes full phase autonomously
- Validates with `mix test` and `mix boundary`
- Updates Phase 1 status to ✓ when complete

**Invocation:**

```
"Use the @phoenix-tdd subagent to implement Phase 1 (Backend Domain + Application) from the plan"
```

**Output:** Phase 1 complete. Domain and application layers fully tested. TodoList.md updated with all checkboxes ticked.

---

#### Implementation Phase 2: Backend Infrastructure + Interface (Use `@phoenix-tdd` subagent again)

**When to delegate:**

- Implementing Phase 2 from architect's plan
- Database, LiveView, Channels, APIs
- Requires Phase 1 to be complete

**What phoenix-tdd does:**

- Reads TodoList.md to understand Phase 2 scope
- Implements Infrastructure Layer (schemas, migrations, queries)
- Implements Interface Layer (LiveViews, controllers, channels, templates)
- **Checks off items in TodoList.md** as they're completed
- Completes ALL checkboxes in Phase 2
- Does NOT ask "should I continue?" - completes full phase autonomously
- Runs migrations, validates with `mix test` and `mix boundary`
- Updates Phase 2 status to ✓ when complete

**Invocation:**

```
"Use the @phoenix-tdd subagent to implement Phase 2 (Backend Infrastructure + Interface) from the plan"
```

**Output:** Phase 2 complete. Full backend implementation with passing tests. TodoList.md updated.

---

**Main Agent Action After Phase 2:**

Before proceeding to Phase 3, Main Agent MUST:

1. **Run Pre-commit Checks:**

   ```bash
   mix precommit
   ```

2. **Fix Any Issues:**
   - If formatter changes code: Review and commit changes
   - If Credo reports warnings: Fix or add `# credo:disable-for-this-file` if justified
   - If Dialyzer reports type errors: Fix type specs
   - If tests fail: Debug and fix failing tests
   - If boundary violations: Refactor to fix violations

3. **Verify Clean State:**
   - All pre-commit checks passing
   - `mix test` passing
   - `mix boundary` clean
   - Code formatted and linted

4. **Update TodoList.md:**
   - Add checkpoint: `- [x] Phase 2 pre-commit checks passing`

**Only after all issues are resolved, proceed to Phase 3.**

---

#### Implementation Phase 3: Frontend Domain + Application (Use `@typescript-tdd` subagent)

**When to delegate:**

- Implementing Phase 3 from architect's plan
- Client-side business logic and use cases
- No browser APIs or LiveView hooks yet

**What typescript-tdd does:**

- Reads TodoList.md to understand Phase 3 scope
- Strictly follows RED-GREEN-REFACTOR cycle
- Implements Domain Layer (pure TypeScript functions, no side effects)
- Implements Application Layer (use cases with mocked dependencies)
- **Checks off items in TodoList.md** as they're completed
- Completes ALL checkboxes in Phase 3
- Does NOT ask "should I continue?" - completes full phase autonomously
- Uses Vitest, validates with `npm test`
- Updates Phase 3 status to ✓ when complete

**Invocation:**

```
"Use the @typescript-tdd subagent to implement Phase 3 (Frontend Domain + Application) from the plan"
```

**Output:** Phase 3 complete. Frontend domain and application layers fully tested. TodoList.md updated.

---

#### Implementation Phase 4: Frontend Infrastructure + Presentation (Use `@typescript-tdd` subagent again)

**When to delegate:**

- Implementing Phase 4 from architect's plan
- Browser APIs, LiveView hooks, Channel clients, DOM interactions
- Requires Phase 3 to be complete

**What typescript-tdd does:**

- Reads TodoList.md to understand Phase 4 scope
- Implements Infrastructure Layer (localStorage, fetch, Channel clients)
- Implements Presentation Layer (LiveView hooks, DOM manipulation)
- **Checks off items in TodoList.md** as they're completed
- Completes ALL checkboxes in Phase 4
- Does NOT ask "should I continue?" - completes full phase autonomously
- Uses Vitest, validates with `npm test`
- Updates Phase 4 status to ✓ when complete

**Invocation:**

```
"Use the @typescript-tdd subagent to implement Phase 4 (Frontend Infrastructure + Presentation) from the plan"
```

**Output:** Phase 4 complete. Full frontend implementation with passing tests. TodoList.md updated.

---

**Main Agent Action After Phase 4:**

Before proceeding to QA phases, Main Agent MUST:

1. **Run Pre-commit Checks:**

   ```bash
   mix precommit
   ```

2. **Fix Any Issues:**
   - If formatter changes code: Review and commit changes
   - If Credo reports warnings: Fix issues
   - If Dialyzer reports type errors: Fix type specs
   - If tests fail: Debug and fix failing tests
   - If boundary violations: Refactor to fix violations
   - If TypeScript errors: Fix type issues in frontend code

3. **Run Frontend Tests:**

   ```bash
   npm test
   ```

   - Fix any failing frontend tests
   - Ensure TypeScript compilation successful

4. **Verify Clean State:**
   - All pre-commit checks passing
   - `mix test` passing (full backend suite)
   - `npm test` passing (full frontend suite)
   - `mix boundary` clean
   - All code formatted and linted

5. **Update TodoList.md:**
   - Add checkpoint: `- [x] Phase 4 pre-commit checks passing`
   - Add checkpoint: `- [x] All implementation phases complete and validated`

**Only after all issues are resolved, proceed to QA Phase 1.**

---

### TodoList.md Workflow

**The TodoList.md file is the central coordination mechanism for all agents.**

**How it works:**

1. **architect agent** creates TodoList.md with all checkboxes organized by phase
2. **Main Agent** reads TodoList.md between phases to track progress
3. **Implementation agents** (phoenix-tdd, typescript-tdd):
   - Read their assigned phase section at start
   - Check off `- [ ]` → `- [x]` as they complete each item
   - Update phase header status when done (⏸ → ⏳ → ✓)
4. **Main Agent Pre-commit Checkpoints** (after Phase 2 and Phase 4):
   - Runs `mix precommit` to catch issues early
   - Fixes formatting, linting, type errors, tests, and boundaries
   - Checks off pre-commit checkpoint items in TodoList.md
   - Ensures clean state before proceeding to next phase
5. **QA agents** (test-validator, code-reviewer):
   - Read their QA phase section
   - Check off validation items as they complete them
   - Update their phase status when done
6. **Main Agent** coordinates handoffs between agents using TodoList.md status

**Status Indicators:**

- ⏸ Not Started - Phase hasn't begun
- ⏳ In Progress - Agent is currently working on this phase
- ✓ Complete - All checkboxes in phase are ticked

**Benefits:**

- Single source of truth for progress tracking
- Clear visibility into what's done and what's remaining
- Agents know exactly what to implement without asking
- **Pre-commit checkpoints catch issues early** (after Phase 2 and 4)
- Clean, validated code before proceeding to next phase
- Easy to resume if interrupted
- Main Agent can see overall feature progress at a glance

---

### Quality Assurance Phases

After implementation is complete, run these quality assurance phases:

#### QA Phase 1: Test Validation (Use `@test-validator` subagent)

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

#### QA Phase 2: Code Review (Use `@code-reviewer` subagent)

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

### The Self-Learning Loop

Each feature implementation strengthens the system:

```
Feature Request
    ↓
Planning Phases:
    ↓
Planning Phase 1 (Optional): [prd] → Gathers requirements
    ↓
Planning Phase 2: [architect] → Creates TDD plan with checkboxes for 4 implementation phases
    ↓
Implementation Phases:
    ↓
    [phoenix-tdd] → Phase 1: Backend Domain + Application
    ↓
    [phoenix-tdd] → Phase 2: Backend Infrastructure + Interface
    ↓
    [typescript-tdd] → Phase 3: Frontend Domain + Application
    ↓
    [typescript-tdd] → Phase 4: Frontend Infrastructure + Presentation
    ↓
Quality Assurance Phases:
    ↓
QA Phase 1: [test-validator] → Validates TDD compliance across all layers
    ↓
QA Phase 2: [code-reviewer] → Ensures architectural integrity
```

### Workflow Benefits

1. **Consistent Quality** - Every feature follows same rigorous process
2. **Knowledge Retention** - Patterns documented as they emerge
3. **TDD Enforcement** - Tests written first (validated automatically)
4. **Boundary Protection** - Architectural violations caught early
5. **Self-Improving** - Each iteration makes next one easier

### Subagent Coordination

**When to use multiple subagents in sequence:**

```
User: "Add real-time notification feature"

Planning Phases:
  Planning Phase 1 (Optional): prd → Gather detailed requirements
  Planning Phase 2: architect → Plan implementation with checkboxes for 4 implementation phases

Implementation Phases:
  Phase 1: phoenix-tdd → Backend domain + application layers
  Phase 2: phoenix-tdd → Backend infrastructure + interface layers
  Phase 3: typescript-tdd → Frontend domain + application layers
  Phase 4: typescript-tdd → Frontend infrastructure + presentation layers

Quality Assurance Phases:
  QA Phase 1: test-validator → Validate all tests
  QA Phase 2: code-reviewer → Review implementation
```

**Key Points:**

- Each implementation phase is **autonomous** - agents complete their full phase
- Agents **DO NOT** ask "should I continue?" - checkboxes define scope
- Each phase has **clear completion criteria** - all checkboxes ticked, tests passing

**When main Agent should handle directly:**

- Simple bug fixes (< 5 lines)
- Documentation-only changes
- Configuration updates
- Exploratory research
- Answering questions about codebase

### Critical Rules

1. **NEVER skip test-validator** - Ensures TDD was followed
2. **NEVER skip code-reviewer** - Catches boundary violations
3. **ALWAYS run in sequence** - Each phase depends on previous
4. **NEVER write implementation before tests** - Non-negotiable

### Subagent Reference

Available subagents in `.opencode/agent/`:

- **prd** - Requirements gathering and PRD creation (optional first step)
- **architect** - Feature planning and TDD design
- **phoenix-tdd** - Phoenix backend and LiveView implementation with TDD
- **typescript-tdd** - TypeScript implementation with TDD (hooks, clients, standalone code)
- **test-validator** - Test quality and TDD process validation
- **code-reviewer** - Architectural and security review

### MCP Tools Integration

All subagents have access to **Context7 MCP tools** for up-to-date library documentation:

**Available MCP Tools:**

- `mcp__context7__resolve-library-id` - Resolve library name to Context7 ID
- `mcp__context7__get-library-docs` - Fetch documentation for a library

**Common Libraries:**

- Phoenix: `/phoenixframework/phoenix`
- Phoenix LiveView: `/phoenixframework/phoenix_live_view`
- Ecto: `/elixir-ecto/ecto`
- Vitest: `/vitest-dev/vitest`
- TypeScript: `/microsoft/TypeScript`
- Mox: `/dashbitco/mox`

**When Subagents Use MCP Tools:**

1. **architect** - Research library capabilities before planning
2. **phoenix-tdd** - Check Phoenix/Elixir testing patterns and API usage
3. **typescript-tdd** - Verify TypeScript patterns and Vitest usage
4. **test-validator** - Validate against official testing guidelines
5. **code-reviewer** - Verify security practices and API usage

**Example Usage:**

```
Subagent needs Phoenix Channel testing patterns:
1. mcp__context7__resolve-library-id("phoenix") → "/phoenixframework/phoenix"
2. mcp__context7__get-library-docs("/phoenixframework/phoenix", topic: "channels")
3. Use documentation to implement/validate correctly
```

This ensures all subagents work with **current, official documentation** rather than outdated patterns.

### Quick Start Example

```
User: "Add user profile avatar upload"

Main agent: "I'll orchestrate this feature through our TDD workflow:

Planning Phases:

  Planning Phase 1 (Optional): First, let me use the prd subagent to gather requirements...
    [Delegates to prd - can skip if requirements are clear]

  Planning Phase 2: The architect subagent will create a comprehensive plan...
    [Delegates to architect]
    Output:
    - Detailed implementation plan
    - TodoList.md created with all checkboxes for 4 implementation phases + 3 QA phases

Implementation Phases:
(All agents read TodoList.md and check off items as they complete them)

  Implementation Phase 1: Backend domain + application layers
    [Main Agent updates TodoList.md Phase 1 status: ⏸ → ⏳]
    [Delegates to phoenix-tdd with Phase 1 scope]
    Output: "Phase 1 complete. All checkboxes ticked. Status updated to ✓"

  Implementation Phase 2: Backend infrastructure + interface layers
    [Main Agent updates TodoList.md Phase 2 status: ⏸ → ⏳]
    [Delegates to phoenix-tdd with Phase 2 scope]
    Output: "Phase 2 complete. All checkboxes ticked. Status updated to ✓"

  Main Agent Pre-commit Checkpoint (After Phase 2):
    [Main Agent runs: mix precommit]
    [Fixes any issues: formatting, Credo, Dialyzer, tests, boundaries]
    [Updates TodoList.md: "- [x] Phase 2 pre-commit checks passing"]
    Output: "All pre-commit checks passing. Ready for Phase 3."

  Implementation Phase 3: Frontend domain + application layers
    [Main Agent updates TodoList.md Phase 3 status: ⏸ → ⏳]
    [Delegates to typescript-tdd with Phase 3 scope]
    Output: "Phase 3 complete. All checkboxes ticked. Status updated to ✓"

  Implementation Phase 4: Frontend infrastructure + presentation layers
    [Main Agent updates TodoList.md Phase 4 status: ⏸ → ⏳]
    [Delegates to typescript-tdd with Phase 4 scope]
    Output: "Phase 4 complete. All checkboxes ticked. Status updated to ✓"

  Main Agent Pre-commit Checkpoint (After Phase 4):
    [Main Agent runs: mix precommit]
    [Main Agent runs: npm test]
    [Fixes any issues: formatting, Credo, Dialyzer, TypeScript, tests, boundaries]
    [Updates TodoList.md: "- [x] Phase 4 pre-commit checks passing"]
    [Updates TodoList.md: "- [x] All implementation phases complete and validated"]
    Output: "All pre-commit checks passing. Full test suite green. Ready for QA."

Quality Assurance Phases:
(All QA agents also use TodoList.md for their checklists)

  QA Phase 1: Verify TDD process across all layers...
    [Main Agent updates TodoList.md QA Phase 1 status: ⏸ → ⏳]
    [Delegates to test-validator]
    Output: "Test validation complete. TodoList.md updated to ✓"

  QA Phase 2: Check architectural compliance...
    [Main Agent updates TodoList.md QA Phase 2 status: ⏸ → ⏳]
    [Delegates to code-reviewer]
    Output: "Code review complete. TodoList.md updated to ✓"

Feature complete! Check TodoList.md - all phases marked ✓"
```

---

## Quick Reference

For detailed documentation on architecture, TDD practices, and implementation guidelines, see:

📖 **Architecture & Design:**

- `docs/prompts/architect/FULLSTACK_TDD.md` - Complete TDD methodology
- `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md` - Phoenix architecture
- `docs/prompts/phoenix/PHOENIX_BEST_PRACTICES.md` - Phoenix conventions
- `docs/prompts/typescript/TYPESCRIPT_DESIGN_PRINCIPLES.md` - Frontend assets architecture

🤖 **Subagent Details:**

- `.opencode/agent/prd.md` - Requirements gathering and PRD creation
- `.opencode/agent/architect.md` - Feature planning process
- `.opencode/agent/phoenix-tdd.md` - Phoenix and LiveView TDD implementation
- `.opencode/agent/typescript-tdd.md` - TypeScript TDD implementation
- `.opencode/agent/test-validator.md` - Test quality validation
- `.opencode/agent/code-reviewer.md` - Code review process

**Key Principles:**

- ✅ **Tests first** - Always write tests before implementation
- ✅ **Boundary enforcement** - Use `mix boundary` to catch violations
- ✅ **SOLID principles** - Single responsibility, dependency inversion, etc.
- ✅ **Clean Architecture** - Domain → Application → Infrastructure → Interface
