# The Self-Learning Loop

Each feature implementation strengthens the system:

```
Feature Request
    ↓
Planning Phases:
    ↓
Planning Phase 1 (Optional): [prd] → Gathers requirements
    ↓
Planning Phase 2 (Optional): [architect] → Creates TDD plan
    ↓
BDD Implementation:
    ↓
Step 1: [fullstack-bdd] → Create .feature file from PRD (RED)
    - Write Gherkin scenarios describing user behavior
    - Write step definitions (tests will FAIL - this is expected)
    - Feature tests are RED (failing) because feature isn't implemented
    ↓
Step 2: [Implement via TDD] → Implement feature units via TDD (RED, GREEN)
    - Use phoenix-tdd for backend (Phases 1-2)
    - Use typescript-tdd for frontend (Phases 3-4)
    - Each unit follows RED-GREEN-REFACTOR
    - Unit tests pass, but feature tests may still be RED
    ↓
Step 3: [fullstack-bdd] → Feature tests pass (GREEN)
    - All unit implementations complete
    - Feature scenarios now pass end-to-end
    - Full-stack integration verified
    ↓
Quality Assurance Phases:
    ↓
QA Phase 1: [test-validator] → Validates TDD compliance across all layers
    ↓
QA Phase 2: [code-reviewer] → Ensures architectural integrity
```

## Workflow Benefits

1. **Consistent Quality** - Every feature follows same rigorous process
2. **Knowledge Retention** - Patterns documented as they emerge
3. **TDD Enforcement** - Tests written first (validated automatically)
4. **Boundary Protection** - Architectural violations caught early
5. **Self-Improving** - Each iteration makes next one easier