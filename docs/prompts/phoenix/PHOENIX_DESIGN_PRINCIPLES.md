# Backend Design Principles: Clean Architecture

This document outlines the core design principles used in this project, focusing on Clean Architecture patterns as they apply to Elixir and Phoenix applications.

## Table of Contents

- [Boundary Library Enforcement](#boundary-library-enforcement)
- [Clean Architecture for Phoenix](#clean-architecture-for-phoenix)
- [Best Practices](#best-practices)

---

## Boundary Library Enforcement

**This project enforces architectural boundaries using the [Boundary](https://hexdocs.pm/boundary) library.**

The Boundary library provides compile-time enforcement of architectural rules, preventing:
- Web layer calling into context internals
- Contexts accessing each other's private modules
- Circular dependencies between contexts

### Core Principles

#### 1. Core vs Interface Separation

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

#### 2. The Dependency Rule

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

#### 3. Context Independence

Each context is a **boundary** that:
- Encapsulates a specific domain area
- Exposes a minimal public API
- Hides internal implementation details
- Communicates with other contexts only through public APIs

### Boundary Configuration

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

### Verifying Architecture

#### Compile-Time Checks

Boundary violations are caught during compilation:

```bash
mix compile
```

**Production code has no boundary warnings** when running `mix compile`. All boundaries are properly declared:

- `Jarga` - Root namespace (top-level, documentation only)
- `JargaApp` - OTP application supervisor
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

#### Pre-commit Checks

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

### Troubleshooting Boundary Violations

#### "Forbidden reference" warning

**Problem**: You're accessing a module that's not exported by its boundary.

**Solution**:
1. Check if the target context has a public function for what you need
2. If not, add one to the context's public API
3. Never directly access internal modules (Queries, Policies, etc.)

#### "Module is not exported" warning

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

#### "Cannot be listed as a dependency" warning

**Problem**: You're listing a module that's not a valid dependency (wrong hierarchy).

**Solution**:
1. Only list sibling boundaries or top-level boundaries as dependencies
2. Don't list parent or child modules

#### Circular dependency

**Problem**: Context A depends on B, and B depends on A.

**Solution**:
1. Extract shared functionality into a third context
2. Or refactor one context to not need the other
3. Consider if both contexts should be merged

### Adding New Contexts

When creating a new context:

1. **Define the boundary** in the context module:

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
   - `new_context/policies/*.ex` - Business rules
   - `new_context/use_cases/*.ex` - Application operations
   - `new_context/infrastructure/*.ex` - Data access

### Best Practices for Boundaries

1. **Keep Contexts Focused**
   - ✅ Accounts, Workspaces, Projects (clear domains)
   - ❌ Helpers, Utils, Common (vague, attract unrelated code)

2. **Minimize Exports**
   - ✅ Schemas used in function signatures
   - ✅ Public context module (implicit)
   - ❌ Internal query modules
   - ❌ Policy modules
   - ❌ Private helper modules

3. **Document Public APIs**
   - Every exported function should have clear documentation
   - Use precise type specs
   - Include usage examples

---

## Clean Architecture for Phoenix

Clean Architecture organizes code into layers with clear dependencies, where inner layers contain business logic and outer layers contain implementation details.

### Layer Structure

```
lib/
├── my_app/                      # Core Context Layer
│   ├── domain/                  # Domain Layer (Pure Business Logic)
│   │   ├── entities/            # Ecto schemas - data structures only
│   │   ├── policies/            # Pure business rules (no I/O)
│   │   └── scope.ex             # Domain value objects
│   ├── application/             # Application Layer (Use Cases)
│   │   └── use_cases/           # Business operation orchestration
│   └── infrastructure/          # Infrastructure Layer (Technical Details)
│       ├── queries/             # Query objects (Ecto queries)
│       ├── repositories/        # Data access abstraction
│       ├── notifiers/           # Email notifications (e.g., UserNotifier)
│       ├── subscribers/         # EventHandler-based cross-context subscribers
│       └── services/            # External API clients
├── my_app_web/                  # Interface Layer (Presentation)
│   ├── controllers/             # HTTP request handlers
│   ├── live/                    # LiveView modules
│   ├── components/              # Reusable UI components
│   └── channels/                # WebSocket channels
└── my_app.ex                    # Public Context API (Facade)
```

### Dependency Rule

**Dependencies flow inward and downward:**

```
Interface Layer (JargaWeb)
    ↓ depends on
Application Layer (Use Cases) → Domain Layer (Policies, Entities)
    ↓ depends on
Infrastructure Layer (Queries, Repositories, Notifiers)
    ↓ depends on
Shared Infrastructure (Repo, Mailer)
```

**Critical Rules:**
- **Domain Layer**: Pure functions only - NO Repo, NO Ecto.Query, NO side effects
- **Application Layer**: Orchestrates domain + infrastructure, defines transactions
- **Infrastructure Layer**: Handles I/O (database, email, external APIs)
- **Interface Layer**: Thin adapters - delegates to application layer

### Architecture Guidelines

#### 1. Domain Layer (Pure Business Logic)

The innermost layer containing pure business logic with **zero infrastructure dependencies**.

**What belongs here:**
- **Entities**: Pure domain value objects (NO Ecto dependencies)
- **Policies**: Pure business rules (NO Repo, NO Ecto.Query, NO I/O)
- **Value Objects**: Domain-specific types (e.g., Scope, Money, Email)

**Domain Entities: Pure Structs**

Domain entities are pure structs with NO Ecto dependencies:

```elixir
defmodule MyContext.Domain.Entities.MyEntity do
  @moduledoc """
  Pure domain entity with no infrastructure dependencies.
  
  For database persistence, see MyContext.Infrastructure.Schemas.MyEntitySchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          status: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :name,
    :status,
    :inserted_at,
    :updated_at
  ]

  @doc "Creates a new entity from attributes"
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc "Converts infrastructure schema to domain entity"
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      name: schema.name,
      status: schema.status,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
```

**Critical Rules:**
- ❌ Domain entities NEVER use `use Ecto.Schema`
- ❌ Domain entities NEVER call `Repo` directly
- ❌ Domain entities NEVER use `Ecto.Query`
- ❌ Domain entities NEVER perform side effects (email, HTTP, password hashing)
- ❌ Domain entities NEVER access environment variables or configuration
- ✅ Domain entities are ALWAYS pure structs with `defstruct`
- ✅ Domain entities provide `new/1` to create from attributes
- ✅ Domain entities provide `from_schema/1` to convert from infrastructure schemas
- ✅ Domain entities are fast to construct and test (no database needed)

**What domain policies SHOULD do:**
- ✅ Pure functions that return boolean or validation results
- ✅ Encapsulate business rules (e.g., "can user invite members?")
- ✅ Fast, deterministic, testable without database

#### 2. Application Layer (Use Cases)

Orchestrates business operations by coordinating domain policies and infrastructure.

**What belongs here:**
- **Use Cases**: One module per business operation
- **Transaction orchestration**: Define where transactions start/end
- **Coordination**: Call domain policies + infrastructure services

**Responsibilities:**
- ✅ Validate inputs using domain policies
- ✅ Orchestrate infrastructure (repositories, notifiers)
- ✅ Define transaction boundaries
- ✅ Handle side effects (email, broadcasts) AFTER transactions
- ✅ Accept dependency injection via `opts` keyword list

**Critical Rules:**
- Use cases are the ONLY place where complex business operations should be orchestrated
- Context modules should delegate to use cases, not implement logic directly
- All major operations (create, update, delete with side effects) should have use cases
- Use cases ensure consistency: all operations follow same patterns

#### 3. Infrastructure Layer

Handles all I/O operations and external dependencies, including **Ecto schemas**.

**What belongs here:**
- **Schemas**: Ecto schemas for database persistence (`infrastructure/schemas/`)
- **Queries**: Ecto query objects (composable, reusable)
- **Repositories**: Data access abstraction (thin wrappers around `Repo`)
- **Notifiers**: Email notification sending (e.g., `UserNotifier`, `WorkspaceNotifier`)
- **Subscribers**: `EventHandler`-based GenServers that react to domain events from other contexts
- **Services**: External API clients, file storage, etc.

**Infrastructure Schemas Pattern**

All Ecto schemas belong in `infrastructure/schemas/` with the `Schema` suffix:

```elixir
defmodule MyContext.Infrastructure.Schemas.MyEntitySchema do
  @moduledoc """
  Ecto schema for [entity] database persistence.
  
  This is the actual database schema. Domain entities in domain/entities/
  are pure structs or wrappers around this schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "my_entities" do
    field(:name, :string)
    # ... all database fields and associations
    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for validation and casting"
  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [:name, ...])
    |> validate_required([:name])
    |> validate_length(:name, max: 255)
    # ... all Ecto validations
  end
end
```

**Characteristics:**
- ✅ All Ecto schemas live in `infrastructure/schemas/` (NOT in `domain/entities/`)
- ✅ Schema modules have `Schema` suffix (e.g., `UserSchema`, `ChatSessionSchema`)
- ✅ All database queries use these schemas directly
- ✅ Repositories and queries reference infrastructure schemas
- ✅ Domain entities are pure structs OR wrappers that delegate to schemas
- ✅ All external I/O (email, HTTP, file system) goes here
- ✅ Testable via dependency injection

**Critical Rules:**
- Infrastructure modules are PRIVATE to the context (not exported via Boundary)
- Never access infrastructure directly from other contexts
- Infrastructure depends on domain, never the reverse
- Domain entities in `domain/entities/` are exported; schemas in `infrastructure/schemas/` are private

#### 4. Interface Layer (Phoenix Web)

Thin adapters that translate external protocols to application operations.

**What belongs here:**
- **LiveViews**: User interface state management
- **Controllers**: HTTP request/response handling
- **Channels**: WebSocket connections
- **Components**: UI presentation logic

**Responsibilities:**
- ✅ Parse and validate HTTP/WebSocket input
- ✅ Call context public API functions
- ✅ Handle errors gracefully with user-friendly messages
- ✅ Manage UI state (assigns, flash messages)
- ❌ NO business logic - delegate to contexts
- ❌ NO direct database access
- ❌ NO direct calls to infrastructure modules

### Context Organization

#### Phoenix Contexts as Public API Facades

The context module (e.g., `Jarga.Accounts`) acts as a **thin facade** over internal layers.

**Context Module Responsibilities:**
- ✅ Expose public API functions (delegates to use cases or queries)
- ✅ Define boundary with `use Boundary` (deps and exports)
- ✅ Keep functions small - just delegation
- ❌ NO complex business logic
- ❌ NO transaction orchestration (belongs in use cases)
- ❌ NO direct database queries (delegate to infrastructure)

**Internal Organization (NOT exported):**
- `domain/entities/` - Pure domain entities (exported via Boundary)
- `domain/policies/` - Pure business rules
- `application/use_cases/` - Business operations
- `infrastructure/schemas/` - Ecto schemas for database persistence
- `infrastructure/queries/` - Query objects
- `infrastructure/repositories/` - Data access
- `infrastructure/notifiers/` - External communications

**Key Principle:** Context module is just a directory with a public API. All real work happens in internal layers.

---

## Best Practices

### 1. Domain Entities and Infrastructure Schemas

**Critical Separation:** Domain entities are pure structs in `domain/entities/`, Ecto schemas are in `infrastructure/schemas/`.

**Domain Entities (Pure Structs)**
```elixir
# lib/my_context/domain/entities/my_entity.ex
defmodule MyContext.Domain.Entities.MyEntity do
  @moduledoc """
  Pure domain entity with no infrastructure dependencies.
  
  For database persistence, see MyContext.Infrastructure.Schemas.MyEntitySchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }
  
  defstruct [:id, :name, :inserted_at, :updated_at]
  
  def new(attrs), do: struct(__MODULE__, attrs)
  
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      name: schema.name,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
```

**Infrastructure Schemas (Ecto)**
```elixir
# lib/my_context/infrastructure/schemas/my_entity_schema.ex
defmodule MyContext.Infrastructure.Schemas.MyEntitySchema do
  @moduledoc """
  Ecto schema for [entity] database persistence.
  
  Domain entity: MyContext.Domain.Entities.MyEntity
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "my_entities" do
    field(:name, :string)
    # ... all database fields and associations
    timestamps(type: :utc_datetime)
  end
  
  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 255)
  end
end
```

**Critical Rules:**
- ✅ Ecto schemas ALWAYS in `infrastructure/schemas/` with `Schema` suffix
- ✅ Domain entities in `domain/entities/` are ALWAYS pure structs (use `defstruct`)
- ✅ Infrastructure schemas handle ALL Ecto concerns (changesets, validations, associations)
- ✅ Domain entities provide `new/1` and `from_schema/1` functions
- ✅ Tests for schemas go in `test/context/infrastructure/schemas/`
- ✅ Fixtures and repositories use infrastructure schemas directly
- ❌ NEVER use `use Ecto.Schema` in domain entities
- ❌ NEVER import `Ecto.Query` in domain layer
- ❌ NEVER call `Repo` in domain layer

**What infrastructure schemas SHOULD contain:**
- ✅ Schema definition (`use Ecto.Schema`, field definitions, associations)
- ✅ Changesets for data validation (format, length, required fields)
- ✅ Simple data transformations (e.g., downcasing email, trimming whitespace)
- ✅ Foreign key constraints and database validations

**What infrastructure schemas MUST NOT contain:**
- ❌ `import Ecto.Query` - queries belong in `infrastructure/queries/`
- ❌ Calls to `Repo` - belongs in repositories or use cases
- ❌ `unsafe_validate_unique` - use in use cases with proper error handling
- ❌ Side effects (password hashing, email sending) - use infrastructure services
- ❌ `System.get_env` or configuration access - use dependency injection
- ❌ Complex business logic - belongs in domain policies or use cases

**Common Violations:**
- Password hashing in changesets → Move to infrastructure service
- `unsafe_validate_unique` in schema → Move to use case with unique constraint error handling
- Query building in schema → Move to `infrastructure/queries/` module
- Token generation logic → Move to infrastructure service

### 2. Dependency Injection for Testability

**All infrastructure dependencies MUST be injectable** via keyword arguments.

**Pattern:**
```elixir
# Use case with injected dependencies
@default_event_bus Perme8.Events.EventBus

def execute(params, opts \\ []) do
  repo = Keyword.get(opts, :repo, Repo)
  event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
  notifier = Keyword.get(opts, :notifier, WorkspaceNotifier)  # For email-only notifiers
  
  # Use injected dependencies
end
```

**Benefits:**
- ✅ Testable without database (inject mocks)
- ✅ Testable without sending emails (inject test notifier)
- ✅ Testable event emission (inject `Perme8.Events.TestEventBus`)
- ✅ Fast unit tests for business logic
- ✅ Clear dependencies visible in function signature

**What to inject:**
- `event_bus` -- `Perme8.Events.EventBus` (primary for domain event emission)
- Repository/Repo access
- Notifiers (email-only, e.g., `WorkspaceNotifier` for invitation emails)
- External API clients
- Time/clock (for testing time-dependent logic)

**What NOT to inject:**
- Domain policies (pure functions, no dependencies)
- Configuration (use Application.get_env)
- Ecto schemas (not dependencies)

### 3. Use Cases for All Business Operations

**When to create a use case:**
- ✅ Operation involves multiple steps (create + notify)
- ✅ Operation requires a transaction
- ✅ Operation has side effects (email, broadcast)
- ✅ Operation involves complex business rules
- ✅ Operation coordinates multiple infrastructure services

**When NOT to create a use case:**
- ❌ Simple read operations (use queries directly)
- ❌ Simple updates with no side effects
- ❌ Operations with no business logic

**Use Case Structure:**
```elixir
defmodule MyContext.Application.UseCases.OperationName do
  @default_event_bus Perme8.Events.EventBus

  def execute(params, opts \\ []) do
    # 1. Extract dependencies
    repo = Keyword.get(opts, :repo, Repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    
    # 2. Validate with domain policies
    # 3. Orchestrate infrastructure within transaction
    result = repo.transact(fn ->
      # ... database operations ...
      {:ok, entity}
    end)

    # 4. Emit domain events AFTER transaction commits
    case result do
      {:ok, entity} ->
        event_bus.emit(%MyContext.Domain.Events.EntityCreated{
          aggregate_id: entity.id,
          actor_id: params.user.id,
          workspace_id: params.workspace_id
        })
        {:ok, entity}

      error ->
        error
    end
  end
end
```

**Critical Rules:**
- Use cases return `{:ok, result}` or `{:error, reason}`
- Context functions delegate to use cases
- Use cases are the ONLY place for complex orchestration
- Never put transaction logic directly in context modules

### 4. Query Objects Pattern

**All Ecto queries belong in `infrastructure/queries/` modules.**

**Principles:**
- ✅ One queries module per entity (e.g., `Queries` for User and UserToken)
- ✅ Return Ecto queryables, NOT results (no `Repo.all`, `Repo.one`)
- ✅ Composable, pipeline-friendly functions
- ✅ Internal to context (not exported)
- ❌ NEVER in domain entities
- ❌ NEVER in use cases (use cases call queries via repositories)

**Structure:**
```elixir
defmodule MyContext.Infrastructure.Queries.Queries do
  import Ecto.Query
  alias MyContext.Domain.Entities.Entity

  # Base query
  def base, do: Entity

  # Composable filters
  def by_id(query \\ base(), id), do: where(query, [e], e.id == ^id)
  def by_status(query, status), do: where(query, [e], e.status == ^status)
  def recent(query, days), do: where(query, [e], e.inserted_at > ago(^days, "day"))
  
  # Preloads
  def with_associations(query), do: preload(query, [:assoc1, :assoc2])
end
```

**Usage:**
- Context functions use queries + `Repo`
- Repositories use queries for data access
- Use cases never build queries directly

### 5. Domain Policies: Pure Business Rules

**Domain policies in `domain/policies/` are PURE FUNCTIONS with zero I/O.**

**Characteristics:**
- ✅ Pure functions returning boolean or validation results
- ✅ No dependencies (no Repo, no Ecto.Query, no HTTP, no email)
- ✅ Deterministic and side-effect free
- ✅ Lightning-fast unit tests (milliseconds, no database)
- ✅ Encapsulate business rules: "Can user X do Y?"

**Structure:**
```elixir
defmodule MyContext.Domain.Policies.MyPolicy do
  @moduledoc """
  Pure business rules for [domain concept].
  
  NO INFRASTRUCTURE DEPENDENCIES.
  """

  @valid_roles [:admin, :member, :guest]

  def valid_role?(role), do: role in @valid_roles
  def can_invite?(user_role), do: user_role in [:admin, :owner]
  def can_delete?(resource_owner, current_user), do: resource_owner == current_user
end
```

**When to use policies:**
- Authorization rules ("can user do this?")
- Business rule validation ("is this allowed?")
- Status transitions ("can order be cancelled?")

**When NOT to use policies:**
- Database queries → Use infrastructure
- Email sending → Use infrastructure
- External API calls → Use infrastructure

### 6. Repository Pattern

**Repositories in `infrastructure/repositories/` abstract data access.**

**Purpose:**
- ✅ Thin wrappers around `Repo` for specific operations
- ✅ Use query objects for query construction
- ✅ Injectable for testing (accept `repo` parameter)
- ✅ Return domain entities, not raw query results
- ✅ Reusable across multiple use cases

**Structure:**
```elixir
defmodule MyContext.Infrastructure.Repositories.EntityRepository do
  @moduledoc """
  Data access for [Entity].
  """

  alias MyContext.Infrastructure.Queries.Queries
  alias MyApp.Repo

  def get_one(query, repo \\ Repo) do
    repo.one(query)
  end

  def get_by_id(id, repo \\ Repo) do
    Queries.by_id(id) |> repo.one()
  end

  def exists?(id, repo \\ Repo) do
    Queries.by_id(id) |> repo.exists?()
  end
end
```

**When to use repositories:**
- Complex query execution logic
- Multiple use cases need same data access pattern
- Want to abstract Repo for testing

**When NOT needed:**
- Simple `Repo.get`, `Repo.all` calls → Use directly in context
- One-off queries → Use queries module + Repo in context

### 7. Context as Thin Facade

**The context module (e.g., `Jarga.Accounts`) should be THIN - just delegation.**

**Anti-pattern: Fat Context**
```elixir
# BAD - Complex logic in context module
def update_user_password(user, attrs) do
  user
  |> User.password_changeset(attrs)
  |> update_user_and_delete_all_tokens()  # Complex transaction logic here
end

defp update_user_and_delete_all_tokens(changeset) do
  Repo.transact(fn ->
    # 20 lines of transaction logic
  end)
end
```

**Pattern: Thin Context Delegating to Use Cases**
```elixir
# GOOD - Context delegates to use case
def update_user_password(user, attrs) do
  UseCases.UpdateUserPassword.execute(%{user: user, attrs: attrs})
end
```

**When context functions get complex:**
- ✅ Create a use case
- ✅ Move transaction logic to use case
- ✅ Move multi-step operations to use case
- ✅ Keep context module under 200 lines

**Context module responsibilities:**
- Delegate to use cases for writes
- Simple reads using queries + Repo
- Define public API
- Maintain boundary configuration

### 8. Configuration and Environment Variables

**Never access configuration or environment variables in domain or application layers.**

**Anti-pattern:**
```elixir
# BAD - Environment access in infrastructure
defp deliver(recipient, subject, body, opts) do
  from_email = System.get_env("SENDGRID_FROM_EMAIL", "noreply@jarga.app")
  # ...
end
```

**Pattern: Inject Configuration**
```elixir
# GOOD - Configuration injected via opts
defp deliver(recipient, subject, body, opts) do
  from_email = Keyword.get(opts, :from_email, default_from_email())
  from_name = Keyword.get(opts, :from_name, default_from_name())
  # ...
end

defp default_from_email do
  Application.get_env(:my_app, :from_email, "noreply@jarga.app")
end
```

**Rules:**
- ✅ Use `Application.get_env` in infrastructure for defaults
- ✅ Accept configuration via `opts` for testability
- ✅ Read environment variables at application startup, not runtime
- ❌ Never use `System.get_env` in request path
- ❌ Never access config in domain policies or entities

### 9. Cross-Context Communication

**Always use public context APIs - never access internal modules.**

**The Boundary library enforces this at compile time.**

**Violations:**
- ❌ `alias OtherContext.Infrastructure.Queries.Queries`
- ❌ `alias OtherContext.Domain.Policies.SomePolicy`
- ❌ `alias OtherContext.Infrastructure.Repositories.SomeRepo`
- ❌ `alias OtherContext.Application.UseCases.SomeUseCase`

**Correct:**
- ✅ `alias OtherContext` (the public API module)
- ✅ `alias OtherContext.Domain.Entities.SomeEntity` (if exported)
- ✅ Call functions on the context: `OtherContext.some_function()`

**How to expose functionality:**
Add public functions to the context module that delegate to internal layers.

**Key Principle:**
If you see a Boundary warning, you're accessing an internal module. Add a public function to the context instead.

### 10. Domain Events and Transactions

**Critical Rule: Always emit events AFTER transactions commit.**

**Why:** Emitting inside a transaction creates race conditions. Listeners may query the database before the transaction commits, seeing stale or missing data.

**Pattern:**
```elixir
@default_event_bus Perme8.Events.EventBus

def execute(params, opts \\ []) do
  event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

  result = Repo.transact(fn ->
    # Database operations
    {:ok, entity}
  end)

  # Emit domain event AFTER transaction commits
  case result do
    {:ok, entity} ->
      event_bus.emit(%MyEvent{
        aggregate_id: entity.id,
        actor_id: params.user.id,
        workspace_id: params.workspace_id
      })
      {:ok, entity}
    error ->
      error
  end
end
```

**Rules:**
- Use `opts[:event_bus]` injection -- never call `Phoenix.PubSub.broadcast` directly from use cases
- Emit structured domain event structs (defined with `use Perme8.Events.DomainEvent`)
- NEVER emit inside `Repo.transact/1` callback (enforced by Credo `NoBroadcastInTransaction` check)
- LiveViews subscribe to `events:workspace:{id}` topics and pattern-match on event structs
- Cross-context subscribers use the `Perme8.Events.EventHandler` behaviour

**Testing:**
- Inject `event_bus: Perme8.Events.TestEventBus` in tests to capture emitted events
- See `docs/prompts/architect/PUBSUB_TESTING_GUIDE.md` for the full testing guide

---

## Summary: Clean Architecture Checklist

When reviewing or writing code, check these principles:

### Domain Layer
- [ ] Entities are data structures only (schemas + changesets)
- [ ] NO `import Ecto.Query` in entities
- [ ] NO `Repo` calls in entities
- [ ] NO side effects (password hashing, email sending) in entities
- [ ] NO `System.get_env` or configuration access
- [ ] Policies are pure functions with zero dependencies
- [ ] Policies contain business rules, not data access

### Application Layer
- [ ] Use cases exist for all complex business operations
- [ ] Use cases define transaction boundaries
- [ ] Use cases accept dependency injection via `opts`
- [ ] Use cases orchestrate domain policies + infrastructure
- [ ] Domain events emitted via `opts[:event_bus]` AFTER transactions

### Infrastructure Layer
- [ ] All Ecto queries in `infrastructure/queries/` modules
- [ ] Queries return queryables, not results
- [ ] Repositories are thin wrappers around Repo
- [ ] Email notifiers handle external email communications
- [ ] EventHandler subscribers handle cross-context reactions
- [ ] Infrastructure depends on domain, not vice versa

### Context Module
- [ ] Context is a thin facade (< 200 lines)
- [ ] Context delegates to use cases for writes
- [ ] Context uses queries + Repo for simple reads
- [ ] NO complex transaction logic in context
- [ ] Boundary configuration properly defined

### Cross-Cutting
- [ ] Boundary library catches all violations
- [ ] No cross-context access to internal modules
- [ ] Dependencies injected, not hardcoded
- [ ] Domain events emitted after transaction commits (never inside `Repo.transact`)
- [ ] Configuration injected via opts, not `System.get_env`

**When in doubt, ask:**
1. Can I test this without a database? (Domain should be yes)
2. Does this module have ONE clear responsibility?
3. Are dependencies injectable?
4. Am I accessing another context's internals? (Should be no)
5. Is business logic in the right layer?
