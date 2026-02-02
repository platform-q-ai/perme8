# Orchestrated Development Workflow

**This project uses specialized subagents to maintain code quality, architectural integrity, and TDD discipline.**

## Feature Implementation Protocol

When implementing a new feature, follow this orchestrated workflow using **Behavior-Driven Development (BDD)** as the default approach:

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

#### Planning Phase 2: Technical Planning (Use `@architect` subagent) - OPTIONAL

**When to delegate:**

- User requests a complex feature that spans multiple layers or contexts
- Feature is large enough to benefit from upfront planning
- You want a structured implementation plan

**What the architect does:**

- Reads architectural documentation
- Creates comprehensive BDD/TDD implementation plan
- Identifies affected boundaries
- Plans BDD implementation steps and supporting unit tests
- **Creates TodoList.md file** with all checkboxes for tracking

**Invocation:**

```
"Use the @architect subagent to plan implementation of [feature]"
```

**Output:**

- Detailed implementation plan with BDD feature scenarios and TDD unit test planning
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
- Organized by Implementation Steps (1-3) and QA Phases (1-2)
- Uses status indicators: ⏸ (Not Started), ⏳ (In Progress), ✓ (Complete)
- Implementation agents check off items as they complete them
- Main Agent updates phase status between agent runs

**Note:** You can skip this phase and go directly to BDD Step 1 for simple, well-understood features.