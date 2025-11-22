# Agents Context Refactoring Proposal

## Executive Summary

This document proposes a comprehensive refactoring of `lib/jarga/agents/` to fully align with the project's Clean Architecture principles and established conventions from other contexts (Accounts, Workspaces, Projects).

**Current Status**: ⚠️ Partially aligned - good structure but several architectural violations

**Goal**: 🎯 100% alignment with architectural patterns, eliminating all violations

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Architectural Violations](#architectural-violations)
3. [Proposed Refactoring](#proposed-refactoring)
4. [Migration Plan](#migration-plan)
5. [Testing Strategy](#testing-strategy)
6. [Benefits](#benefits)

---

## Current State Analysis

### What's Working Well ✅

1. **Clean Layer Separation**
   - Proper domain/application/infrastructure organization
   - Clear use case pattern adoption
   - Good repository pattern usage

2. **Pure Domain Logic**
   - `AgentCloner` in domain layer is pure (no I/O)
   - Entity schemas are data structures only
   - Good separation of concerns

3. **Use Case Adoption**
   - All major operations have dedicated use cases
   - Thin context facade delegating to use cases

4. **Boundary Configuration**
   - Properly declared as top-level boundary
   - Correct dependencies (Accounts, Workspaces, Projects, Repo)
   - Exports only domain entities (Agent, ChatSession, ChatMessage)

### Current Structure

```
lib/jarga/agents/
├── application/
│   ├── policies/
│   │   ├── agent_policy.ex           # ⚠️ Should be in domain
│   │   └── visibility_policy.ex      # ⚠️ Should be in domain
│   ├── services/
│   │   └── llm_client.ex             # ⚠️ Should be in infrastructure
│   └── use_cases/
│       ├── agent_query.ex
│       ├── create_session.ex
│       └── ... (17 use cases total)
├── domain/
│   ├── entities/
│   │   ├── agent.ex
│   │   ├── chat_message.ex
│   │   ├── chat_session.ex
│   │   └── workspace_agent_join.ex
│   └── agent_cloner.ex               # ✅ Correct location
├── infrastructure/
│   ├── notifiers/
│   │   └── pub_sub_notifier.ex
│   ├── queries/
│   │   ├── agent_queries.ex
│   │   └── queries.ex
│   ├── repositories/
│   │   ├── agent_repository.ex
│   │   ├── session_repository.ex
│   │   └── workspace_agent_repository.ex
│   └── services/
│       └── behaviours/
│           └── llm_client_behaviour.ex  # ⚠️ Should move up
└── agents.ex (context module)
```

---

## Architectural Violations

### 1. Policies in Application Layer ❌

**Current Location**: `application/policies/`
- `agent_policy.ex` - Pure business rules
- `visibility_policy.ex` - Pure business rules

**Problem**: 
- Policies contain NO I/O or infrastructure dependencies
- They are **pure domain logic** (boolean rules based on data)
- Application layer is for **orchestration**, not pure rules

**Evidence from Project Guidelines**:
> "Domain policies in `domain/policies/` are PURE FUNCTIONS with zero I/O."
> (PHOENIX_DESIGN_PRINCIPLES.md, line 575)

**Established Pattern** (from Workspaces context):
```
lib/jarga/workspaces/
  domain/
    policies/
      authorization.ex        # Pure business rules
      membership_policy.ex    # Pure business rules
```

**Violation Severity**: 🔴 **HIGH** - Breaks core Clean Architecture principle

---

### 2. LlmClient in Application Layer ❌

**Current Location**: `application/services/llm_client.ex`

**Problem**:
- LlmClient performs **external HTTP I/O**
- Uses `Req` library for API calls
- Handles configuration and environment variables
- This is **infrastructure concern**, not application orchestration

**Evidence from Project Guidelines**:
> "Infrastructure Layer handles all I/O operations and external dependencies... External API clients"
> (PHOENIX_DESIGN_PRINCIPLES.md, lines 387-388)

**Established Pattern** (from Accounts context):
```
lib/jarga/accounts/
  infrastructure/
    notifiers/
      user_notifier.ex     # External I/O (email sending)
```

**Violation Severity**: 🔴 **HIGH** - External I/O must be in infrastructure

---

### 3. Behaviour Location Inconsistency ⚠️

**Current Location**: `infrastructure/services/behaviours/llm_client_behaviour.ex`

**Problem**:
- Nested too deep (`services/behaviours/`)
- Inconsistent with simpler module organization
- Should be alongside implementation for discoverability

**Established Pattern**:
- Keep module hierarchies flat
- Behaviours alongside implementations

**Violation Severity**: 🟡 **MEDIUM** - Organizational clarity

---

### 4. Missing Domain Policies ⚠️

**Gap Identified**:
- No policies for chat session operations
- Missing workspace membership verification policy
- No policy for agent workspace association rules

**Impact**:
- Business rules scattered across use cases
- Harder to test authorization logic
- Reduces reusability of business rules

**Violation Severity**: 🟡 **MEDIUM** - Missing best practice adoption

---

## Proposed Refactoring

### Phase 1: Move Policies to Domain Layer

**Move**:
```
FROM: application/policies/agent_policy.ex
TO:   domain/policies/agent_policy.ex

FROM: application/policies/visibility_policy.ex  
TO:   domain/policies/visibility_policy.ex
```

**Rationale**:
- Policies are pure business rules (no I/O)
- Aligns with Workspaces/Projects patterns
- Enables millisecond-fast tests without DB

**Changes Required**:
1. Move files to `domain/policies/`
2. Update module paths in use cases
3. Update tests to `ExUnit.Case, async: true` (no DB)

**Impact**: 
- ✅ Zero breaking changes (internal modules)
- ✅ Faster tests
- ✅ Clearer architecture

---

### Phase 2: Move LlmClient to Infrastructure Layer

**Restructure**:
```
FROM: application/services/llm_client.ex
TO:   infrastructure/services/llm_client.ex

FROM: infrastructure/services/behaviours/llm_client_behaviour.ex
TO:   infrastructure/services/llm_client_behaviour.ex
```

**Rationale**:
- LlmClient performs external HTTP I/O
- Configuration access and API calls are infrastructure
- Follows pattern: "External API clients" → Infrastructure
- Behaviour should be alongside implementation

**Changes Required**:
1. Move `llm_client.ex` to `infrastructure/services/`
2. Move `llm_client_behaviour.ex` up one level
3. Update module aliases in context and use cases
4. Update behaviour `@behaviour` reference

**Impact**:
- ✅ Zero breaking changes (internal modules)
- ✅ Clear separation: I/O in infrastructure
- ✅ Easier to mock/test

---

### Phase 3: Add Missing Domain Policies

**New Files**:
```
domain/policies/session_policy.ex
domain/policies/workspace_association_policy.ex
```

**Session Policy** (`domain/policies/session_policy.ex`):
```elixir
defmodule Jarga.Agents.Domain.Policies.SessionPolicy do
  @moduledoc """
  Pure business rules for chat session permissions.
  
  NO INFRASTRUCTURE DEPENDENCIES.
  """

  @doc "Can user access this session?"
  @spec can_access_session?(session, user_id) :: boolean()
  def can_access_session?(%{user_id: owner_id}, user_id) 
    when owner_id == user_id, do: true
  def can_access_session?(_session, _user_id), do: false

  @doc "Can user delete this session?"
  @spec can_delete_session?(session, user_id) :: boolean()
  def can_delete_session?(%{user_id: owner_id}, user_id) 
    when owner_id == user_id, do: true
  def can_delete_session?(_session, _user_id), do: false

  @doc "Can user delete this message?"
  @spec can_delete_message?(message, user_id) :: boolean()
  def can_delete_message?(%{user_id: owner_id}, user_id) 
    when owner_id == user_id, do: true
  def can_delete_message?(_message, _user_id), do: false
end
```

**Workspace Association Policy** (`domain/policies/workspace_association_policy.ex`):
```elixir
defmodule Jarga.Agents.Domain.Policies.WorkspaceAssociationPolicy do
  @moduledoc """
  Pure business rules for agent-workspace associations.
  
  NO INFRASTRUCTURE DEPENDENCIES.
  """

  @doc """
  Can user add agent to workspace?
  
  Rules:
  - User must be agent owner
  - User must be workspace member (checked by caller)
  """
  @spec can_add_to_workspace?(agent, user_id) :: boolean()
  def can_add_to_workspace?(%{user_id: owner_id}, user_id) 
    when owner_id == user_id, do: true
  def can_add_to_workspace?(_agent, _user_id), do: false

  @doc "Can user remove agent from workspace?"
  @spec can_remove_from_workspace?(agent, user_id) :: boolean()
  def can_remove_from_workspace?(%{user_id: owner_id}, user_id) 
    when owner_id == user_id, do: true
  def can_remove_from_workspace?(_agent, _user_id), do: false

  @doc """
  Is agent visible in workspace?
  
  Rules:
  - User's own agents (any visibility)
  - Other users' SHARED agents
  """
  @spec visible_in_workspace?(agent, user_id) :: boolean()
  def visible_in_workspace?(%{user_id: owner_id}, user_id) 
    when owner_id == user_id, do: true
  def visible_in_workspace?(%{visibility: "SHARED"}, _user_id), do: true
  def visible_in_workspace?(_agent, _user_id), do: false
end
```

**Rationale**:
- Extract business rules from use cases
- Enable fast, pure testing
- Improve reusability across operations

**Impact**:
- ✅ Better testability
- ✅ Clearer business logic
- ✅ Follows domain-driven design

---

### Phase 4: Flatten Infrastructure Services

**Restructure**:
```
FROM: infrastructure/services/behaviours/llm_client_behaviour.ex
TO:   infrastructure/services/llm_client_behaviour.ex
```

**Rationale**:
- Simpler, flatter structure
- Behaviour alongside implementation
- Easier discovery and maintenance

**Impact**:
- ✅ Simpler navigation
- ✅ Consistent with project patterns

---

### Final Structure (After Refactoring)

```
lib/jarga/agents/
├── domain/
│   ├── entities/
│   │   ├── agent.ex
│   │   ├── chat_message.ex
│   │   ├── chat_session.ex
│   │   └── workspace_agent_join.ex
│   ├── policies/                              # ✅ MOVED HERE
│   │   ├── agent_policy.ex                    # Pure business rules
│   │   ├── visibility_policy.ex               # Pure business rules
│   │   ├── session_policy.ex                  # NEW: Session rules
│   │   └── workspace_association_policy.ex    # NEW: Association rules
│   └── agent_cloner.ex                        # Pure domain logic
│
├── application/
│   └── use_cases/
│       ├── agent_query.ex
│       ├── create_session.ex
│       ├── save_message.ex
│       ├── delete_message.ex
│       ├── load_session.ex
│       ├── list_sessions.ex
│       ├── delete_session.ex
│       ├── list_user_agents.ex
│       ├── create_user_agent.ex
│       ├── update_user_agent.ex
│       ├── delete_user_agent.ex
│       ├── clone_shared_agent.ex
│       ├── list_workspace_available_agents.ex
│       ├── list_viewable_agents.ex
│       ├── validate_agent_params.ex
│       ├── sync_agent_workspaces.ex
│       ├── add_agent_to_workspace.ex
│       ├── remove_agent_from_workspace.ex
│       └── prepare_context.ex
│
└── infrastructure/
    ├── queries/
    │   ├── agent_queries.ex
    │   └── queries.ex                         # Session/message queries
    ├── repositories/
    │   ├── agent_repository.ex
    │   ├── session_repository.ex
    │   └── workspace_agent_repository.ex
    ├── services/                              # ✅ MOVED HERE
    │   ├── llm_client.ex                      # External API client (HTTP I/O)
    │   └── llm_client_behaviour.ex            # Flattened from behaviours/
    └── notifiers/
        └── pub_sub_notifier.ex
```

---

## Migration Plan

### Step 1: Move Policies to Domain Layer

**Files to Move**:
1. `application/policies/agent_policy.ex` → `domain/policies/agent_policy.ex`
2. `application/policies/visibility_policy.ex` → `domain/policies/visibility_policy.ex`

**Files to Update**:
```elixir
# Use cases that import policies
application/use_cases/clone_shared_agent.ex
application/use_cases/update_user_agent.ex
application/use_cases/delete_user_agent.ex
application/use_cases/list_viewable_agents.ex
application/use_cases/list_workspace_available_agents.ex

# Update aliases from:
alias Jarga.Agents.Application.Policies.AgentPolicy
# To:
alias Jarga.Agents.Domain.Policies.AgentPolicy
```

**Tests to Update**:
```elixir
# test/jarga/agents/application/policies/agent_policy_test.exs
# Move to:
test/jarga/agents/domain/policies/agent_policy_test.exs

# Update to use ExUnit.Case (no DB):
use ExUnit.Case, async: true  # Instead of DataCase
```

**Validation**:
- ✅ `mix compile` - No warnings
- ✅ `mix test` - All tests pass
- ✅ `mix boundary` - No violations

---

### Step 2: Move LlmClient to Infrastructure

**Files to Move**:
1. `application/services/llm_client.ex` → `infrastructure/services/llm_client.ex`
2. `infrastructure/services/behaviours/llm_client_behaviour.ex` → `infrastructure/services/llm_client_behaviour.ex`

**Files to Update**:
```elixir
# Context module (lib/jarga/agents.ex)
alias Jarga.Agents.Application.Services.LlmClient
# Change to:
alias Jarga.Agents.Infrastructure.Services.LlmClient

# Use cases
application/use_cases/agent_query.ex
# Update alias

# Behaviour reference in LlmClient
@behaviour Jarga.Agents.Infrastructure.Services.Behaviours.LlmClientBehaviour
# Change to:
@behaviour Jarga.Agents.Infrastructure.Services.LlmClientBehaviour
```

**Tests to Update**:
```elixir
# test/jarga/agents/application/services/llm_client_test.exs
# Move to:
test/jarga/agents/infrastructure/services/llm_client_test.exs
```

**Validation**:
- ✅ `mix compile` - No warnings
- ✅ `mix test` - All tests pass
- ✅ `mix boundary` - No violations

---

### Step 3: Add New Domain Policies

**New Files to Create**:
1. `domain/policies/session_policy.ex`
2. `domain/policies/workspace_association_policy.ex`

**Tests to Create**:
1. `test/jarga/agents/domain/policies/session_policy_test.exs`
2. `test/jarga/agents/domain/policies/workspace_association_policy_test.exs`

**Use Cases to Refactor** (extract business rules to policies):
```elixir
# delete_session.ex
# Before:
if session.user_id != user_id, do: {:error, :not_found}

# After:
alias Jarga.Agents.Domain.Policies.SessionPolicy
unless SessionPolicy.can_delete_session?(session, user_id) do
  {:error, :forbidden}
end

# Similar refactoring for:
# - delete_message.ex
# - load_session.ex
# - add_agent_to_workspace.ex
# - remove_agent_from_workspace.ex
```

**Validation**:
- ✅ `mix test test/jarga/agents/domain/policies/` - New policy tests pass
- ✅ `mix test` - All existing tests still pass
- ✅ Business rules testable in isolation (< 1ms per test)

---

### Step 4: Delete Empty Directories

**Directories to Remove**:
```bash
# After all moves complete:
rm -rf lib/jarga/agents/application/policies
rm -rf lib/jarga/agents/application/services
rm -rf lib/jarga/agents/infrastructure/services/behaviours
```

**Validation**:
- ✅ `mix compile` - Clean compilation
- ✅ No orphaned files

---

### Step 5: Update Documentation

**Files to Update**:
1. Context module docstring (`lib/jarga/agents.ex`)
   - Update architecture description to reflect new structure
   
2. Create/update README (optional)
   - Document policy locations
   - Explain service organization

---

## Testing Strategy

### Phase 1: Policy Tests

**Convert to Pure Unit Tests**:
```elixir
# test/jarga/agents/domain/policies/agent_policy_test.exs
defmodule Jarga.Agents.Domain.Policies.AgentPolicyTest do
  use ExUnit.Case, async: true  # ✅ No DB needed
  
  alias Jarga.Agents.Domain.Policies.AgentPolicy
  
  describe "can_edit?/2" do
    test "owner can edit their agent" do
      agent = %{user_id: "user-123"}
      assert AgentPolicy.can_edit?(agent, "user-123")
    end
    
    test "non-owner cannot edit agent" do
      agent = %{user_id: "owner-123"}
      refute AgentPolicy.can_edit?(agent, "other-456")
    end
  end
  
  # ✅ Each test runs in < 1ms
  # ✅ No database setup/teardown
  # ✅ Fully isolated and deterministic
end
```

**Benefits**:
- ⚡ **1000x faster** tests (< 1ms vs seconds)
- ✅ **Fully deterministic** (no DB state)
- ✅ **Easy to understand** (pure function testing)

---

### Phase 2: Infrastructure Tests

**LlmClient Tests** (with mocking):
```elixir
# test/jarga/agents/infrastructure/services/llm_client_test.exs
defmodule Jarga.Agents.Infrastructure.Services.LlmClientTest do
  use ExUnit.Case, async: false  # HTTP mocking
  
  # Use bypass or mox to mock HTTP calls
  # Test error handling, streaming, etc.
end
```

---

### Phase 3: Integration Tests

**Use Case Tests** (existing - should still pass):
```elixir
# test/jarga/agents/application/use_cases/*_test.exs
# These tests should continue working with zero changes
# They test full orchestration with DB
```

---

## Benefits

### 1. Architectural Clarity ✅

**Before**: 
- Policies mixed with orchestration (application layer)
- External I/O in application layer
- Confusing: "Is this pure logic or I/O?"

**After**:
- Clear separation: Domain = pure, Infrastructure = I/O
- Easy to understand: "Where should this code go?"
- Aligns 100% with project guidelines

---

### 2. Testability ⚡

**Before**:
- Policy tests might use DataCase unnecessarily
- Slower test suite
- Harder to test edge cases

**After**:
- Domain policies: Pure unit tests (< 1ms each)
- Infrastructure: Clear I/O mocking boundaries
- **Estimated 10x faster domain test suite**

**Example**:
```elixir
# Before: ~50ms per test (with DB setup)
# After: < 1ms per test (pure functions)
# 
# For 50 policy tests: 2.5 seconds → 50ms saved per run
```

---

### 3. Consistency Across Contexts 🎯

**Current Inconsistency**:
- Workspaces: `domain/policies/`
- Projects: `domain/policies/`
- Agents: `application/policies/` ❌

**After Refactoring**:
- Workspaces: `domain/policies/` ✅
- Projects: `domain/policies/` ✅
- Agents: `domain/policies/` ✅

**Developer Experience**:
- "Where are policies?" → **Always** `domain/policies/`
- "Where are external API clients?" → **Always** `infrastructure/services/`
- No mental overhead switching between contexts

---

### 4. Better Reusability 🔄

**Example**:
```elixir
# Policy can be used in multiple use cases
alias Jarga.Agents.Domain.Policies.SessionPolicy

# In LoadSession use case:
unless SessionPolicy.can_access_session?(session, user_id) do
  {:error, :forbidden}
end

# In DeleteSession use case:
unless SessionPolicy.can_delete_session?(session, user_id) do
  {:error, :forbidden}
end

# In ListSessions use case (future):
sessions
|> Enum.filter(&SessionPolicy.can_access_session?(&1, user_id))
```

**Without Policies**:
- Business rules duplicated across use cases
- Harder to maintain consistency
- Risk of divergent implementations

---

### 5. Easier Onboarding 👥

**New Developer**:
> "Where do I put authorization logic for agents?"

**Before**: 
- "Uh... some in application/policies, some in use cases?"

**After**: 
- "Domain policies - it's pure business rules with no I/O"
- Points to docs/PHOENIX_DESIGN_PRINCIPLES.md
- Same pattern as every other context

---

### 6. No Breaking Changes 🛡️

**Critical**:
- All moved modules are **internal** (not exported)
- Context public API (`Jarga.Agents.*`) unchanged
- Web layer has **zero changes**
- Existing tests work with minimal updates

**Risk**: **VERY LOW** ✅

---

## Implementation Checklist

### Pre-flight Checks
- [ ] Review proposal with team
- [ ] Confirm testing strategy
- [ ] Schedule implementation window

### Execution (Can be done incrementally)

#### Step 1: Policies to Domain (1-2 hours)
- [ ] Move `agent_policy.ex` to `domain/policies/`
- [ ] Move `visibility_policy.ex` to `domain/policies/`
- [ ] Update use case imports
- [ ] Move/update tests
- [ ] Run `mix test` - confirm green
- [ ] Run `mix boundary` - confirm clean
- [ ] Commit: "refactor: move agent policies to domain layer"

#### Step 2: LlmClient to Infrastructure (1-2 hours)
- [ ] Move `llm_client.ex` to `infrastructure/services/`
- [ ] Move `llm_client_behaviour.ex` up one level
- [ ] Update context module alias
- [ ] Update use case imports
- [ ] Update behaviour `@behaviour` reference
- [ ] Move/update tests
- [ ] Run `mix test` - confirm green
- [ ] Run `mix boundary` - confirm clean
- [ ] Commit: "refactor: move llm_client to infrastructure layer"

#### Step 3: Add New Policies (2-3 hours)
- [ ] Create `session_policy.ex` with tests
- [ ] Create `workspace_association_policy.ex` with tests
- [ ] Refactor use cases to use new policies
- [ ] Run `mix test` - confirm green
- [ ] Commit: "feat: add session and workspace association policies"

#### Step 4: Cleanup (30 mins)
- [ ] Delete empty `application/policies/` directory
- [ ] Delete empty `application/services/` directory
- [ ] Delete empty `infrastructure/services/behaviours/` directory
- [ ] Update context docstring
- [ ] Run `mix test` - final green check
- [ ] Run `mix boundary` - final clean check
- [ ] Commit: "chore: cleanup empty directories and update docs"

### Post-implementation
- [ ] Full test suite passes (`mix test`)
- [ ] No boundary violations (`mix boundary`)
- [ ] Pre-commit checks pass (`mix precommit`)
- [ ] Update CHANGELOG (if applicable)
- [ ] Team review/walkthrough

---

## Estimated Effort

| Phase | Effort | Risk |
|-------|--------|------|
| 1. Move Policies | 1-2 hours | Low |
| 2. Move LlmClient | 1-2 hours | Low |
| 3. Add New Policies | 2-3 hours | Medium |
| 4. Cleanup & Docs | 30 mins | Low |
| **TOTAL** | **5-7.5 hours** | **Low-Medium** |

**Can be split into 4 separate commits** for incremental progress.

---

## Risk Assessment

### Low Risk ✅
- All changes are internal module moves
- No public API changes
- Boundary library will catch any mistakes
- Tests validate correctness at each step

### Medium Risk ⚠️
- Adding new policies requires refactoring use cases
- Need to ensure authorization logic is correctly extracted

### Mitigation
- Move in small, incremental steps (4 phases)
- Run tests after each phase
- Each commit is independently deployable
- Easy to rollback if issues arise

---

## Alternatives Considered

### Alternative 1: Leave as-is
**Pros**: Zero effort
**Cons**: 
- Continues architectural debt
- Inconsistent with other contexts
- Harder for new developers
- Slower test suite (policies not pure)

**Verdict**: ❌ Not recommended

---

### Alternative 2: Only move policies
**Pros**: Smaller change, addresses main inconsistency
**Cons**: 
- LlmClient still in wrong layer (I/O in application)
- Incomplete alignment

**Verdict**: ⚠️ Better than nothing, but incomplete

---

### Alternative 3: Full refactoring (recommended) ✅
**Pros**: 
- Complete architectural alignment
- All benefits listed above
- Establishes strong foundation for future

**Cons**: 
- More work (5-7.5 hours)

**Verdict**: ✅ **RECOMMENDED** - Best long-term investment

---

## Conclusion

This refactoring addresses architectural violations while maintaining zero breaking changes to the public API. The proposed changes:

1. **Align Agents context with established patterns** (Workspaces, Projects)
2. **Improve testability** through pure domain policies
3. **Clarify architecture** by moving I/O to infrastructure
4. **Add missing policies** for better business rule encapsulation
5. **Simplify onboarding** through consistency

**Recommendation**: ✅ **Proceed with full refactoring**

The low risk and high benefit make this a worthwhile investment. The work can be done incrementally in 4 phases, with each commit independently reviewed and deployed.

---

## Questions & Discussion

1. **Should we create the new policies (Phase 3) or just move existing?**
   - Recommendation: Do both - moving is low-hanging fruit, new policies add real value

2. **Can we defer any phases?**
   - Phases 1-2 should be done together (consistency)
   - Phase 3 (new policies) could be deferred if time-constrained
   - Phase 4 (cleanup) should follow 1-2 immediately

3. **Any concerns about test coverage?**
   - Current coverage should be maintained
   - New policies should have 100% coverage (they're pure functions)

4. **Timeline?**
   - Can be completed in one focused day
   - Or split across multiple days (one phase per day)

---

## References

- [docs/prompts/backend/PHOENIX_DESIGN_PRINCIPLES.md](../prompts/backend/PHOENIX_DESIGN_PRINCIPLES.md)
- [docs/prompts/backend/PHOENIX_BEST_PRACTICES.md](../prompts/backend/PHOENIX_BEST_PRACTICES.md)
- [docs/BOUNDARY_QUICK_REFERENCE.md](../BOUNDARY_QUICK_REFERENCE.md)

---

**Prepared by**: Architect Agent
**Date**: November 22, 2025
**Status**: 📋 Proposal (Awaiting Approval)
