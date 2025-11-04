# Architecture Documentation

## Overview

This project follows **Clean Architecture** principles with a clear separation between the **Core** (business logic) and the **Interface** (web layer). We use the [Boundary](https://hexdocs.pm/boundary) library to automatically enforce these architectural rules at compile time.

The architecture is inspired by the articles:
- [Towards Maintainable Elixir: The Development Process](https://www.veribigthings.com/posts/towards-maintainable-elixir-the-development-process)
- [Towards Maintainable Elixir: The Core and the Interface](https://www.veribigthings.com/posts/towards-maintainable-elixir-the-core-and-the-interface)

## Core Principles

### 1. Core vs Interface Separation

The codebase is organized into two main layers:

**Core Layer** (`lib/jarga/`)
- Contains all business logic and domain rules
- Independent of how clients access the system (REST, GraphQL, WebSocket)
- Cannot depend on the web layer
- Contexts are the public API of the core

**Interface Layer** (`lib/jarga_web/`)
- Adapts external requests to core operations
- Handles protocol-specific concerns (HTTP, WebSocket)
- Normalizes and validates input before passing to core
- Can depend on core, but not vice versa

### 2. The Dependency Rule

```
Interface Layer (JargaWeb)
    ↓ can call
Core Layer (Contexts: Accounts, Workspaces, Projects)
    ↓ can use
Shared Infrastructure (Repo, Mailer)
```

**Dependencies flow inward**:
- Interface depends on Core
- Core depends on Infrastructure
- Core never depends on Interface
- Infrastructure depends on nothing

### 3. Context Independence

Each context is a **boundary** that:
- Encapsulates a specific domain area
- Exposes a minimal public API
- Hides internal implementation details
- Communicates with other contexts only through public APIs

## Boundary Configuration

### What is Boundary?

Boundary is a library that enforces architectural rules at compile time. It prevents:
- Web layer calling into context internals
- Contexts accessing each other's private modules
- Circular dependencies between contexts

### Layer Definitions

#### Interface Layer: `JargaWeb`

**Location**: `lib/jarga_web.ex:21`

```elixir
use Boundary,
  deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Projects, Jarga.Repo, Jarga.Mailer],
  exports: []
```

- **Can depend on**: All core contexts and shared infrastructure
- **Exports**: Nothing (web modules are never imported by core)
- **Contains**: Controllers, LiveViews, Components, Channels, Plugs

#### Core Context: `Jarga.Accounts`

**Location**: `lib/jarga/accounts.ex:9`

```elixir
use Boundary,
  deps: [Jarga.Repo, Jarga.Mailer],
  exports: [{User, []}, {Scope, []}]
```

- **Can depend on**: Shared infrastructure only
- **Exports**: `User` and `Scope` schemas (used by other contexts)
- **Private**: `UserToken`, `UserNotifier` (internal implementation)

#### Core Context: `Jarga.Workspaces`

**Location**: `lib/jarga/workspaces.ex:14`

```elixir
use Boundary,
  deps: [Jarga.Accounts, Jarga.Repo],
  exports: [{Workspace, []}]
```

- **Can depend on**: Accounts context and shared infrastructure
- **Exports**: `Workspace` schema
- **Private**:
  - `WorkspaceMember` (schema)
  - `Queries` (infrastructure - query objects)
  - `Policies.MembershipPolicy` (domain - business rules)
  - `UseCases.*` (application - orchestration)
  - `Infrastructure.MembershipRepository` (infrastructure - data access)
  - `Services.*` (infrastructure - external services)

#### Core Context: `Jarga.Projects`

**Location**: `lib/jarga/projects.ex:14`

```elixir
use Boundary,
  deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Repo],
  exports: [{Project, []}]
```

- **Can depend on**: Accounts, Workspaces, and shared infrastructure
- **Exports**: `Project` schema
- **Private**: `Queries`, `Policies`

#### Shared Infrastructure: `Jarga.Repo` and `Jarga.Mailer`

**Location**: `lib/jarga/repo.ex:4`, `lib/jarga/mailer.ex:4`

```elixir
use Boundary, top_level?: true, deps: []
```

- **Can depend on**: Nothing (foundation layer)
- **Available to**: All contexts and web layer
- **Purpose**: Shared technical infrastructure

## Guidelines by Layer

### Interface Layer (Web)

#### What Belongs Here

✅ **DO** put here:
- HTTP request/response handling
- Input normalization and validation (schemaless changesets)
- Protocol-specific logic (GraphQL resolvers, LiveView events)
- Rendering and view logic
- Session management

❌ **DON'T** put here:
- Business rules and validations
- Direct database queries
- Complex domain logic
- Email composition

#### Input Normalization Pattern

The interface layer must normalize weakly-typed input (query params, form data) into well-typed structures before passing to core.

**Example: Controller Action**

```elixir
# lib/jarga_web/live/app_live/workspaces/show.ex:179
def handle_event("create_project", %{"project" => project_params}, socket) do
  user = socket.assigns.current_scope.user
  workspace_id = socket.assigns.workspace.id

  # Delegate to core - interface doesn't validate business rules
  case Projects.create_project(user, workspace_id, project_params) do
    {:ok, _project} ->
      # Handle success

    {:error, %Ecto.Changeset{} = changeset} ->
      # Handle validation error

    {:error, _reason} ->
      # Handle authorization error
  end
end
```

**Key Points**:
- Extract and normalize parameters from socket/conn
- Call context function with well-typed arguments
- Handle different error cases appropriately
- Don't access internal context modules

### Core Layer (Contexts)

The Core Layer is further organized into three sub-layers following Clean Architecture:

```
Core Layer (lib/jarga/)
├── Domain Layer       (Pure business logic, no I/O)
│   ├── Entities       (Schemas - data structures)
│   └── Policies       (Business rules - pure functions)
├── Application Layer  (Use cases, orchestration)
│   └── UseCases       (Coordinate domain + infrastructure)
└── Infrastructure     (Data access, external services)
    ├── Queries        (Database query objects)
    └── Repositories   (Data access abstraction)
```

#### Domain Layer

**Pure business logic with zero external dependencies.**

✅ **DO** put here:
- Business rules and validation logic
- Domain policies (pure functions)
- Value object transformations
- Business calculations

❌ **DON'T** put here:
- Database queries (use Repo, Ecto.Query)
- External API calls
- File I/O
- Any side effects

**Example: Pure Domain Policy**
```elixir
# lib/jarga/workspaces/policies/membership_policy.ex
defmodule Jarga.Workspaces.Policies.MembershipPolicy do
  @moduledoc """
  Pure domain policy with no infrastructure dependencies.
  All functions are side-effect free and deterministic.
  """

  def valid_invitation_role?(role), do: role in [:admin, :member, :guest]
  def can_change_role?(role), do: role not in [:owner]
  def can_remove_member?(role), do: role not in [:owner]
end
```

#### Application Layer

**Orchestrates domain logic with infrastructure.**

✅ **DO** put here:
- Use cases (business operations)
- Transaction boundaries
- Orchestration of domain + infrastructure
- Side effect coordination (emails, notifications)

❌ **DON'T** put here:
- HTTP-specific code
- Pure business rules (put in domain)
- Direct SQL (use query objects)

**Example: Use Case**
```elixir
# lib/jarga/workspaces/use_cases/invite_member.ex
def execute(params, opts) do
  with :ok <- validate_role(params.role),                    # Domain policy
       {:ok, workspace} <- verify_membership(...),            # Infrastructure
       :ok <- check_not_already_member(...),                 # Infrastructure
       user <- find_user(...) do                             # Infrastructure
    add_member(workspace, user, params.role)                 # Infrastructure
    send_notification(user, workspace)                       # Side effect
  end
end
```

#### Infrastructure Layer

**Data access and external service integration.**

✅ **DO** put here:
- Database queries (Ecto, Repo)
- Query objects
- Repository pattern implementations
- External API clients
- Email delivery
- File storage

❌ **DON'T** put here:
- Business rules
- HTTP request handling
- Session management

#### Context Public API Pattern

Each context module exports a clean public API with clear type specs.

**Example: Context Function**

```elixir
# lib/jarga/workspaces.ex:48
@doc """
Creates a workspace for a user.

Automatically adds the creating user as an owner of the workspace.
"""
@spec create_workspace(User.t(), map()) ::
  {:ok, Workspace.t()} | {:error, Ecto.Changeset.t()}
def create_workspace(%User{} = user, attrs) do
  Repo.transact(fn ->
    with {:ok, workspace} <- create_workspace_record(attrs),
         {:ok, _member} <- add_member_as_owner(workspace, user) do
      {:ok, workspace}
    end
  end)
end
```

**Key Points**:
- Clear, descriptive function names
- Precise type specifications (not `map()` or `any()`)
- Comprehensive documentation
- Business rules enforced here (e.g., creator becomes owner)
- Private helper functions for internal logic

#### Cross-Context Communication

When one context needs functionality from another, use the public API only.

**❌ BAD - Accessing internal modules**:

```elixir
# DON'T DO THIS
alias Jarga.Workspaces.Policies.Authorization, as: WorkspaceAuth

def create_project(user, workspace_id, attrs) do
  # Directly accessing internal policy module
  case WorkspaceAuth.verify_membership(user, workspace_id) do
    # ...
  end
end
```

**✅ GOOD - Using public API**:

```elixir
# lib/jarga/projects.ex:63
alias Jarga.Workspaces

def create_project(user, workspace_id, attrs) do
  # Call public context API
  case Workspaces.verify_membership(user, workspace_id) do
    {:ok, _workspace} ->
      # Create project
    {:error, reason} ->
      {:error, reason}
  end
end
```

The Workspaces context exposes this as a public function:

```elixir
# lib/jarga/workspaces.ex:222
@doc """
Verifies that a user is a member of a workspace.

This is a public API for other contexts to verify workspace membership.
"""
def verify_membership(%User{} = user, workspace_id) do
  get_workspace(user, workspace_id)
end
```

#### Internal Organization Patterns

##### Query Objects Pattern

Extract complex queries into dedicated query modules within the context.

```elixir
# lib/jarga/workspaces/queries.ex
defmodule Jarga.Workspaces.Queries do
  @moduledoc """
  Query objects for workspace data access.
  This module is internal to the Workspaces context.
  """

  import Ecto.Query
  alias Jarga.Workspaces.{Workspace, WorkspaceMember}

  def base do
    from(w in Workspace)
  end

  def for_user(query, %User{id: user_id}) do
    query
    |> join(:inner, [w], wm in WorkspaceMember, on: wm.workspace_id == w.id)
    |> where([w, wm], wm.user_id == ^user_id)
  end

  def active(query) do
    where(query, [w], is_nil(w.archived_at))
  end

  def ordered(query) do
    order_by(query, [w], desc: w.inserted_at)
  end
end
```

**Usage in context**:

```elixir
# lib/jarga/workspaces.ex:28
def list_workspaces_for_user(%User{} = user) do
  Queries.base()
  |> Queries.for_user(user)
  |> Queries.active()
  |> Queries.ordered()
  |> Repo.all()
end
```

**Benefits**:
- Composable queries
- Reusable across context functions
- Testable in isolation
- Clear separation from business logic

##### Domain Policy Pattern

**Pure domain policies** contain business rules with no infrastructure dependencies.

```elixir
# lib/jarga/workspaces/policies/membership_policy.ex
defmodule Jarga.Workspaces.Policies.MembershipPolicy do
  @moduledoc """
  Pure domain policy for workspace membership business rules.

  No infrastructure dependencies - pure functions only.
  """

  @allowed_invitation_roles [:admin, :member, :guest]
  @protected_roles [:owner]

  def valid_invitation_role?(role), do: role in @allowed_invitation_roles
  def valid_role_change?(role), do: role in @allowed_invitation_roles
  def can_change_role?(member_role), do: member_role not in @protected_roles
  def can_remove_member?(member_role), do: member_role not in @protected_roles
end
```

**Benefits**:
- Testable without database
- No side effects
- Clear, focused business rules
- Fast unit tests

##### Repository Pattern

**Infrastructure repositories** handle data access and abstract database queries.

```elixir
# lib/jarga/workspaces/infrastructure/membership_repository.ex
defmodule Jarga.Workspaces.Infrastructure.MembershipRepository do
  @moduledoc """
  Repository for workspace membership data access.

  Infrastructure layer - handles database queries.
  """

  alias Jarga.Repo
  alias Jarga.Workspaces.Queries

  def get_workspace_for_user(user, workspace_id, repo \\ Repo) do
    Queries.for_user_by_id(user, workspace_id)
    |> repo.one()
  end

  def workspace_exists?(workspace_id, repo \\ Repo) do
    case Queries.exists?(workspace_id) |> repo.one() do
      count when count > 0 -> true
      _ -> false
    end
  end

  def find_member_by_email(workspace_id, email, repo \\ Repo) do
    Queries.find_member_by_email(workspace_id, email)
    |> repo.one()
  end
end
```

**Benefits**:
- Encapsulates data access
- Allows dependency injection for testing
- Clear separation from business logic
- Reusable across use cases

##### Use Cases Pattern

**Use cases** implement business operations by orchestrating domain policies and infrastructure.

```elixir
# lib/jarga/workspaces/use_cases/use_case.ex
defmodule Jarga.Workspaces.UseCases.UseCase do
  @moduledoc """
  Behavior for use cases in the application layer.

  Use cases encapsulate business operations and orchestrate domain logic,
  infrastructure services, and side effects.
  """

  @callback execute(params :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}
end
```

**Example: InviteMember Use Case**
```elixir
# lib/jarga/workspaces/use_cases/invite_member.ex
defmodule Jarga.Workspaces.UseCases.InviteMember do
  @behaviour Jarga.Workspaces.UseCases.UseCase

  alias Jarga.Workspaces.Policies.MembershipPolicy
  alias Jarga.Workspaces.Infrastructure.MembershipRepository

  @impl true
  def execute(params, opts \\ []) do
    with :ok <- validate_role(params.role),                      # Domain policy
         {:ok, workspace} <- verify_membership(...),              # Infrastructure
         :ok <- check_not_already_member(...),                   # Infrastructure
         user <- find_user(...) do                               # Infrastructure
      add_member_and_notify(workspace, user, params, opts)       # Infrastructure + side effects
    end
  end

  # Apply pure domain policy
  defp validate_role(role) do
    if MembershipPolicy.valid_invitation_role?(role) do
      :ok
    else
      {:error, :invalid_role}
    end
  end

  # Use infrastructure for data access
  defp verify_membership(inviter, workspace_id) do
    case MembershipRepository.get_workspace_for_user(inviter, workspace_id) do
      nil -> {:error, :unauthorized}
      workspace -> {:ok, workspace}
    end
  end
end
```

**Benefits**:
- Single Responsibility: Each use case handles one business operation
- Testable: Can inject mock repositories and notifiers
- Clear flow: Read top-to-bottom what the operation does
- Transaction boundaries: Define where database transactions occur

**Context delegates to use cases**:
```elixir
# lib/jarga/workspaces.ex
def invite_member(inviter, workspace_id, email, role, opts \\ []) do
  params = %{
    inviter: inviter,
    workspace_id: workspace_id,
    email: email,
    role: role
  }

  InviteMember.execute(params, opts)
end
```

##### Authorization Error Handling Pattern

Context functions should provide both safe and unsafe versions for authorization checks:

**Safe version** - Returns error tuples:
```elixir
# lib/jarga/workspaces.ex:114
@spec get_workspace(User.t(), binary()) ::
  {:ok, Workspace.t()} | {:error, :unauthorized | :workspace_not_found}
def get_workspace(%User{} = user, id) do
  # Uses infrastructure repository for data access
  case MembershipRepository.get_workspace_for_user(user, id) do
    nil ->
      if MembershipRepository.workspace_exists?(id) do
        {:error, :unauthorized}
      else
        {:error, :workspace_not_found}
      end

    workspace ->
      {:ok, workspace}
  end
end
```

**Unsafe version** - Raises on error (for cases where user must have access):
```elixir
# lib/jarga/workspaces.ex:133
@spec get_workspace!(User.t(), binary()) :: Workspace.t()
def get_workspace!(%User{} = user, id) do
  Queries.for_user_by_id(user, id)
  |> Repo.one!()
end
```

**Interface layer handling** - LiveViews should use safe versions and handle errors gracefully:

```elixir
# lib/jarga_web/live/app_live/workspaces/show.ex:279
def mount(%{"id" => workspace_id}, _session, socket) do
  user = socket.assigns.current_scope.user

  case Workspaces.get_workspace(user, workspace_id) do
    {:ok, workspace} ->
      # Load data and render page
      {:ok, assign(socket, :workspace, workspace)}

    {:error, :unauthorized} ->
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this workspace")
       |> push_navigate(to: ~p"/app/workspaces")}

    {:error, :workspace_not_found} ->
      {:ok,
       socket
       |> put_flash(:error, "Workspace not found")
       |> push_navigate(to: ~p"/app/workspaces")}
  end
end
```

**Key principles**:
- **Distinguish authorization from existence**: Return `:unauthorized` when resource exists but user lacks access, `:resource_not_found` when it doesn't exist
- **Provide both safe and unsafe versions**: Safe for user-facing operations, unsafe for system operations where access is guaranteed
- **Handle all error cases in interface**: Never let technical errors (like `Ecto.NoResultsError`) reach the user
- **Consistent error semantics**: Use atoms like `:unauthorized`, `:workspace_not_found`, `:invalid_role` for business errors
- **User-friendly messages**: Convert technical error atoms to readable flash messages in the interface layer

**Testing authorization**:

Test authorization at three levels:

1. **Domain policy level** - Fast unit tests for business rules (no database):
```elixir
# test/jarga/workspaces/policies/membership_policy_test.exs
test "valid_invitation_role?/1 returns true for admin, member, guest" do
  assert MembershipPolicy.valid_invitation_role?(:admin)
  assert MembershipPolicy.valid_invitation_role?(:member)
  assert MembershipPolicy.valid_invitation_role?(:guest)
  refute MembershipPolicy.valid_invitation_role?(:owner)
end

test "can_change_role?/1 prevents changing owner role" do
  refute MembershipPolicy.can_change_role?(:owner)
  assert MembershipPolicy.can_change_role?(:admin)
  assert MembershipPolicy.can_change_role?(:member)
end
```

2. **Context level** - Integration tests for safe/unsafe versions (with database):
```elixir
# test/jarga/workspaces_test.exs
test "get_workspace/2 returns :unauthorized when user is not a member" do
  user = user_fixture()
  other_user = user_fixture()
  workspace = workspace_fixture(other_user)

  assert {:error, :unauthorized} = Workspaces.get_workspace(user, workspace.id)
end

test "get_workspace!/2 raises when user is not a member" do
  user = user_fixture()
  other_user = user_fixture()
  workspace = workspace_fixture(other_user)

  assert_raise Ecto.NoResultsError, fn ->
    Workspaces.get_workspace!(user, workspace.id)
  end
end
```

3. **Interface level** - End-to-end tests for user experience:
```elixir
# test/jarga_web/live/app_live/workspaces_test.exs
test "redirects with error when user is not a member of workspace" do
  user = user_fixture()
  other_user = user_fixture()
  workspace = workspace_fixture(other_user)
  conn = build_conn() |> log_in_user(user)

  {:error, {:live_redirect, %{to: path, flash: flash}}} =
    live(conn, ~p"/app/workspaces/#{workspace.id}")

  assert path == ~p"/app/workspaces"
  assert %{"error" => "You don't have access to this workspace"} = flash
end
```

### Shared Infrastructure

#### Jarga.Repo

**Purpose**: Database access wrapper

**Available to**: All contexts and web layer (for direct queries when needed)

**Extensions**: The Repo module includes helper functions:

```elixir
# Example: Transaction wrapper
def transact(fun) do
  transaction(fn ->
    case fun.() do
      {:ok, result} -> result
      {:error, reason} -> rollback(reason)
    end
  end)
end
```

#### Jarga.Mailer

**Purpose**: Email delivery infrastructure

**Available to**: All contexts (for sending transactional emails)

**Note**: Email **content** composition belongs in contexts (often using Phoenix views/templates), but delivery infrastructure is shared.

## Adding New Features

### Adding a New Context

1. **Create the context module** with Boundary configuration:

```elixir
defmodule Jarga.NewContext do
  use Boundary,
    deps: [Jarga.Repo, Jarga.Accounts],  # List dependencies
    exports: [{NewContext.Entity, []}]    # Export only what's needed

  # Public API functions
end
```

2. **Update dependent boundaries**:

```elixir
# lib/jarga_web.ex - if web needs access
use Boundary,
  deps: [..., Jarga.NewContext],
  exports: []
```

3. **Create internal organization**:
   - `new_context/entity.ex` - Schema
   - `new_context/queries.ex` - Query objects
   - `new_context/policies/authorization.ex` - Business rules

### Adding a New Web Feature

1. **Create LiveView/Controller** in `lib/jarga_web/`

2. **Normalize input** using schemaless changesets or params validation

3. **Delegate to context**:

```elixir
def handle_event("action", params, socket) do
  user = socket.assigns.current_user

  case MyContext.perform_action(user, params) do
    {:ok, result} ->
      {:noreply, assign(socket, :result, result)}
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, reason)}
  end
end
```

4. **Handle results** - update UI state, show flash messages, redirect

### Adding Cross-Context Functionality

When a context needs to use another context's functionality:

1. **Check if public API exists** in the target context

2. **If not, add public function** to target context:

```elixir
# In target context
@doc """
Public API for other contexts to verify something.
"""
def verify_something(params) do
  InternalModule.verify_something(params)
end
```

3. **Use public API** from calling context:

```elixir
# In calling context
alias Jarga.TargetContext

def my_function(params) do
  case TargetContext.verify_something(params) do
    {:ok, result} -> # proceed
    {:error, reason} -> {:error, reason}
  end
end
```

## Verifying Architecture

### Compile-Time Checks

Boundary violations are caught during compilation:

```bash
mix compile
```

**Production code has no boundary warnings** when running `mix compile`. All boundaries are properly declared:

- `Jarga` - Root namespace (top-level, documentation only)
- `JargaApp` - OTP application supervisor (renamed from `Jarga.Application` to match logical model)
- `Jarga.Accounts`, `Jarga.Workspaces`, `Jarga.Projects` - Domain contexts (top-level boundaries)
- `Jarga.Repo`, `Jarga.Mailer` - Shared infrastructure (top-level boundaries)
- `JargaWeb` - Web interface layer

**Test-related warnings** may appear for test support modules (DataCase, Fixtures) but these don't affect production code.

If you see warnings like:

```
warning: forbidden reference to Jarga.Workspaces.Policies.Authorization
  (module Jarga.Workspaces.Policies.Authorization is not exported by its owner boundary Jarga.Workspaces)
  lib/jarga/projects.ex:62
```

This means you're accessing an internal module. Use the context's public API instead.

### Running Tests

```bash
mix test
```

All tests must pass. Architecture changes should not break functionality.

### Pre-commit Checks

The precommit task includes boundary verification:

```bash
mix precommit
```

This runs:
- Compilation with warnings as errors
- Boundary checks (automatic during compilation)
- Code formatting
- Credo (style guide)
- Test suite

## Troubleshooting

### "Forbidden reference" warning

**Problem**: You're accessing a module that's not exported by its boundary.

**Solution**:
1. Check if the target context has a public function for what you need
2. If not, add one to the context's public API
3. Never directly access internal modules (Queries, Policies, etc.)

### "Module is not exported" warning

**Problem**: You're trying to use a schema or module not exported by its boundary.

**Solution**:
1. If the schema needs to be shared, add it to the `exports` list
2. If it's internal-only, access it through context functions instead

**Example**:

```elixir
# Add to exports if needed by other boundaries
use Boundary,
  exports: [{MySchema, []}]
```

### "Cannot be listed as a dependency" warning

**Problem**: You're listing a module that's not a valid dependency (wrong hierarchy).

**Solution**:
1. Only list sibling boundaries or top-level boundaries as dependencies
2. Don't list parent or child modules

### Circular dependency

**Problem**: Context A depends on B, and B depends on A.

**Solution**:
1. Extract shared functionality into a third context
2. Or refactor one context to not need the other
3. Consider if both contexts should be merged

## Best Practices

### 1. Keep Contexts Focused

Each context should represent a cohesive domain area:
- ✅ Accounts, Workspaces, Projects (clear domains)
- ❌ Helpers, Utils, Common (vague, attract unrelated code)

### 2. Minimize Exports

Only export what's truly needed by other boundaries:
- ✅ Schemas used in function signatures
- ✅ Public context module (implicit)
- ❌ Internal query modules
- ❌ Policy modules
- ❌ Private helper modules

### 3. Use Type Specs

Always use precise type specs for public functions:

```elixir
# ✅ GOOD
@spec create_workspace(User.t(), map()) ::
  {:ok, Workspace.t()} | {:error, Ecto.Changeset.t()}

# ❌ BAD
@spec create_workspace(any(), any()) :: any()
```

### 4. Document Public APIs

Every exported function should have clear documentation:

```elixir
@doc """
Creates a workspace for a user.

The creating user is automatically added as an owner of the workspace.

## Examples

    iex> create_workspace(user, %{name: "My Workspace"})
    {:ok, %Workspace{}}

    iex> create_workspace(user, %{name: ""})
    {:error, %Ecto.Changeset{}}
"""
```

### 5. Transaction Boundaries

Contexts define transaction boundaries. If multiple operations must succeed or fail together, wrap them in a transaction:

```elixir
def create_workspace(%User{} = user, attrs) do
  Repo.transact(fn ->
    with {:ok, workspace} <- create_workspace_record(attrs),
         {:ok, _member} <- add_member_as_owner(workspace, user) do
      {:ok, workspace}
    end
  end)
end
```

### 6. Return Consistent Error Tuples

Always return `{:ok, result}` or `{:error, reason}`:

```elixir
# ✅ GOOD
{:ok, workspace}
{:error, %Ecto.Changeset{}}
{:error, :unauthorized}

# ❌ BAD
workspace  # Doesn't allow error handling
nil        # Ambiguous
raise "error"  # Don't raise for business logic errors
```

## Migration Guide

### From Unstructured Phoenix App

If migrating from a standard Phoenix app without boundaries:

1. **Add Boundary dependency** and compiler configuration (already done)

2. **Identify your contexts** - what are your main domain areas?

3. **Add Boundary to contexts** one at a time:
   - Start with the most independent context
   - Add `use Boundary` with minimal exports
   - Fix compilation warnings
   - Test thoroughly

4. **Add Boundary to web layer** after all contexts are done

5. **Refactor cross-context calls** to use public APIs only

6. **Extract internal modules** (queries, policies) from context modules

### Gradual Adoption

You don't have to do everything at once:

1. Start with `externals_mode: :relaxed` (already configured)
2. Add boundaries to new code first
3. Gradually add boundaries to existing contexts
4. Fix violations as you encounter them

## Resources

- [Boundary Hex Docs](https://hexdocs.pm/boundary)
- [VBT: The Development Process](https://www.veribigthings.com/posts/towards-maintainable-elixir-the-development-process)
- [VBT: The Core and the Interface](https://www.veribigthings.com/posts/towards-maintainable-elixir-the-core-and-the-interface)
- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

## Summary

This architecture enforces:
- ✅ Clear separation between business logic and presentation
- ✅ Context independence and encapsulation
- ✅ Explicit dependencies between layers
- ✅ Compile-time verification of architectural rules
- ✅ Easier testing, refactoring, and maintenance

The boundary library automates enforcement, so violations are caught immediately during development rather than becoming technical debt.
