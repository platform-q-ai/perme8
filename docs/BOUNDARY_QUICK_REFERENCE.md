# Boundary Quick Reference

Quick reference guide for working with architectural boundaries in this project.

## Quick Checks

### Am I following the architecture?

```bash
# Compile and check for boundary violations
mix compile

# Run full precommit checks
mix precommit
```

✅ **Success**: No "forbidden reference" warnings
❌ **Problem**: See [Troubleshooting](#troubleshooting) below

**Note**: Two informational warnings are expected and can be ignored:
```
warning: Jarga is not included in any boundary
warning: Jarga.Application is not included in any boundary
```
These are harmless - they just indicate modules that don't participate in boundary checking. See [Expected Warnings](#expected-warnings) below.

## Common Patterns

### ✅ Calling a Context from Web Layer

**DO THIS**:

```elixir
# lib/jarga_web/live/some_live.ex
def handle_event("create", params, socket) do
  user = socket.assigns.current_user

  # Call context public API
  case Workspaces.create_workspace(user, params) do
    {:ok, workspace} ->
      # Handle success
    {:error, changeset} ->
      # Handle error
  end
end
```

### ❌ Accessing Internal Context Modules from Web

**DON'T DO THIS**:

```elixir
# lib/jarga_web/live/some_live.ex
alias Jarga.Workspaces.Queries  # ❌ Internal module

def mount(_params, _session, socket) do
  # ❌ Directly accessing internal query module
  workspaces = Queries.base() |> Repo.all()
  # ...
end
```

**FIX**: Use context public API

```elixir
# lib/jarga_web/live/some_live.ex
def mount(_params, _session, socket) do
  user = socket.assigns.current_user
  # ✅ Use public context API
  workspaces = Workspaces.list_workspaces_for_user(user)
  # ...
end
```

### ✅ Cross-Context Communication

**DO THIS**:

```elixir
# lib/jarga/projects.ex
defmodule Jarga.Projects do
  alias Jarga.Workspaces  # ✅ Use context module

  def create_project(user, workspace_id, attrs) do
    # ✅ Call public API
    case Workspaces.verify_membership(user, workspace_id) do
      {:ok, _workspace} ->
        # Create project
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### ❌ Accessing Internal Modules Across Contexts

**DON'T DO THIS**:

```elixir
# lib/jarga/projects.ex
defmodule Jarga.Projects do
  # ❌ Accessing internal policy module
  alias Jarga.Workspaces.Policies.Authorization

  def create_project(user, workspace_id, attrs) do
    # ❌ Direct access to internal module
    case Authorization.verify_membership(user, workspace_id) do
      # ...
    end
  end
end
```

**FIX**: Request public API be added to target context

```elixir
# First, add public function to Workspaces context:
# lib/jarga/workspaces.ex
defmodule Jarga.Workspaces do
  @doc "Public API for other contexts to verify membership"
  def verify_membership(user, workspace_id) do
    Policies.Authorization.verify_membership(user, workspace_id)
  end
end

# Then use it:
# lib/jarga/projects.ex
defmodule Jarga.Projects do
  alias Jarga.Workspaces

  def create_project(user, workspace_id, attrs) do
    case Workspaces.verify_membership(user, workspace_id) do
      # ...
    end
  end
end
```

### ✅ Using Exported Schemas

**DO THIS**:

```elixir
# lib/jarga/projects.ex
alias Jarga.Accounts.User  # ✅ User is exported by Accounts

@spec create_project(User.t(), binary(), map()) ::
  {:ok, Project.t()} | {:error, term()}
def create_project(%User{} = user, workspace_id, attrs) do
  # Use User schema in type spec and pattern matching
end
```

### ❌ Using Non-Exported Schemas

**DON'T DO THIS**:

```elixir
# lib/jarga/projects.ex
alias Jarga.Workspaces.WorkspaceMember  # ❌ Not exported

def some_function do
  # ❌ Cannot use internal schema directly
  %WorkspaceMember{}
end
```

**FIX**: Either:
1. Use context function that returns the data you need
2. Request the schema be exported (if truly needed across boundaries)

### ✅ Creating Internal Modules

**DO THIS**:

```elixir
# lib/jarga/workspaces/queries.ex
defmodule Jarga.Workspaces.Queries do
  @moduledoc """
  Internal query objects for Workspaces context.
  NOT exported - used only within this context.
  """

  import Ecto.Query

  def base, do: from(w in Workspace)
  def for_user(query, user), do: where(query, ...)
  def active(query), do: where(query, [w], is_nil(w.archived_at))
end
```

**Used ONLY within same context**:

```elixir
# lib/jarga/workspaces.ex
defmodule Jarga.Workspaces do
  alias Jarga.Workspaces.Queries  # ✅ Same context

  def list_workspaces_for_user(user) do
    Queries.base()
    |> Queries.for_user(user)
    |> Queries.active()
    |> Repo.all()
  end
end
```

## Boundary Declarations

### Context Boundary

```elixir
defmodule Jarga.MyContext do
  use Boundary,
    deps: [
      Jarga.Repo,           # Can use Repo
      Jarga.OtherContext    # Can call OtherContext public API
    ],
    exports: [
      {MySchema, []}        # Export schema for other boundaries
    ]

  # Public API functions...
end
```

### Web Boundary

```elixir
defmodule JargaWeb do
  use Boundary,
    deps: [
      Jarga.Accounts,      # Can call Accounts API
      Jarga.Workspaces,    # Can call Workspaces API
      Jarga.Projects,      # Can call Projects API
      Jarga.Repo           # Can use Repo (for direct queries if needed)
    ],
    exports: []            # Web layer doesn't export anything
end
```

### Infrastructure Boundary

```elixir
defmodule Jarga.Repo do
  use Boundary,
    top_level?: true,     # Available to all
    deps: []              # Depends on nothing
end
```

## Expected Warnings

### All Boundaries Properly Declared ✅

**Production code** has no boundary warnings when running `mix compile`.

All modules have proper boundary declarations:
- `Jarga` - Root namespace (top-level, documentation only)
- `JargaApp` - OTP application supervisor (renamed from `Jarga.Application` to avoid namespace hierarchy conflicts)
- `Jarga.Accounts`, `Jarga.Workspaces`, `Jarga.Projects` - Domain contexts (top-level boundaries)
- `Jarga.Repo`, `Jarga.Mailer` - Shared infrastructure (top-level boundaries)
- `JargaWeb` - Web interface layer

**Test support modules** may show warnings during `mix test` but these are test-only utilities and don't affect production code boundaries.

## Troubleshooting

### "forbidden reference" Warning

```
warning: forbidden reference to Jarga.Workspaces.Policies.Authorization
  (module Jarga.Workspaces.Policies.Authorization is not exported by its owner boundary Jarga.Workspaces)
  lib/jarga/projects.ex:62
```

**Problem**: Accessing an internal module from another boundary.

**Solution**: Use the context's public API instead.

1. Check if public function exists in target context
2. If not, add it:

```elixir
# In Jarga.Workspaces
def verify_membership(user, workspace_id) do
  Policies.Authorization.verify_membership(user, workspace_id)
end
```

3. Use public API:

```elixir
# In Jarga.Projects
Workspaces.verify_membership(user, workspace_id)
```

### "Module is not exported" Warning

```
warning: Jarga.Accounts.UserToken is not exported by Jarga.Accounts
```

**Problem**: Trying to use a schema/module that's not exported.

**Solutions**:

1. **If schema needs to be shared**, add to exports:

```elixir
use Boundary,
  exports: [{UserToken, []}]
```

2. **If it's internal-only**, use context functions instead:

```elixir
# Instead of accessing UserToken directly
# Use context function
Accounts.generate_user_session_token(user)
```

### "Cannot be listed as a dependency"

```
warning: Jarga.Workspaces.Queries can't be listed as a dependency
```

**Problem**: Listed a non-boundary module as a dependency.

**Solution**: Only list context modules (boundaries) as dependencies:

```elixir
# ❌ Wrong
use Boundary,
  deps: [Jarga.Workspaces.Queries]  # Internal module

# ✅ Correct
use Boundary,
  deps: [Jarga.Workspaces]  # Context boundary
```

## Adding New Code

### Adding a New Context

```elixir
# 1. Create context module with boundary
defmodule Jarga.NewContext do
  use Boundary,
    deps: [Jarga.Repo, Jarga.Accounts],  # Dependencies
    exports: [{NewContext.Schema, []}]    # Exports

  # 2. Public API
  def create_thing(user, attrs), do: ...
  def list_things(user), do: ...

  # 3. Private helpers
  defp internal_function, do: ...
end

# 4. Create schema
defmodule Jarga.NewContext.Schema do
  use Ecto.Schema
  # ...
end

# 5. Create internal modules (queries, policies)
defmodule Jarga.NewContext.Queries do
  # These are NOT exported, only used within context
end

# 6. Update web boundary if needed
# lib/jarga_web.ex
use Boundary,
  deps: [..., Jarga.NewContext]  # Add to deps
```

### Adding a New LiveView

```elixir
# 1. Create LiveView
defmodule JargaWeb.MyLive do
  use JargaWeb, :live_view

  # 2. Import context (public API only)
  alias Jarga.Workspaces

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # 3. Call context public API
    workspaces = Workspaces.list_workspaces_for_user(user)

    {:ok, assign(socket, workspaces: workspaces)}
  end

  def handle_event("create", params, socket) do
    user = socket.assigns.current_user

    # 4. Delegate to context
    case Workspaces.create_workspace(user, params) do
      {:ok, workspace} ->
        {:noreply, socket}
      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
```

## Key Rules

1. ✅ **Web can call Contexts** - but only public APIs
2. ❌ **Contexts cannot call Web** - no web dependencies in core
3. ✅ **Contexts can call other Contexts** - through public APIs only
4. ❌ **Never access internal modules** - Queries, Policies, etc.
5. ✅ **Export only what's needed** - schemas used across boundaries
6. ✅ **Use type specs** - document your public API clearly

## Benefits

- 🔒 **Enforced at compile time** - violations caught immediately
- 📚 **Self-documenting** - clear what's public vs private
- 🔄 **Easier refactoring** - internal changes don't break consumers
- 🧪 **Better testability** - clear boundaries enable focused testing
- 👥 **Team coordination** - explicit contracts between modules

## Further Reading

- [docs/ARCHITECTURE.md](ARCHITECTURE.md) - Complete architecture documentation
- [Boundary Hex Docs](https://hexdocs.pm/boundary) - Library documentation
- [VBT Articles](https://www.veribigthings.com/posts/towards-maintainable-elixir-the-core-and-the-interface) - Architectural inspiration
