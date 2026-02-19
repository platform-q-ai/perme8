# Bounded Context Structure with Layer Boundaries

This document defines the standard architecture pattern for all apps in this monorepo.

## Overview

We use **Bounded Contexts with Layer Boundaries** - a pattern that combines:
- **Vertical slicing** (bounded contexts) for feature isolation
- **Horizontal layers** (Clean Architecture) within each context
- **Compile-time enforcement** via the Boundary library

## Directory Structure

```
lib/
├── {context}/                    # e.g., accounts/, agents/, chat/
│   ├── {context}.ex              # Public API + Context Boundary
│   ├── domain.ex                 # Domain Layer Boundary
│   ├── domain/
│   │   ├── entities/             # Pure domain structs
│   │   │   └── user.ex
│   │   ├── events/               # Domain event structs (use Perme8.Events.DomainEvent)
│   │   │   └── user_registered.ex
│   │   ├── policies/             # Business rules (pure functions)
│   │   │   └── authentication_policy.ex
│   │   └── services/             # Domain services (pure functions)
│   │       └── token_builder.ex
│   ├── application.ex            # Application Layer Boundary
│   ├── application/
│   │   ├── use_cases/            # Orchestration logic
│   │   │   └── register_user.ex
│   │   └── services/             # Application services
│   │       └── password_service.ex
│   ├── infrastructure.ex         # Infrastructure Layer Boundary
│   └── infrastructure/
│       ├── schemas/              # Ecto schemas (DB representation)
│       │   └── user_schema.ex
│       ├── repos/                # Repository implementations
│       │   └── user_repo.ex
│       ├── queries/              # Ecto query builders
│       │   └── user_queries.ex
│       ├── subscribers/          # EventHandler-based cross-context subscribers
│       │   └── invitation_subscriber.ex
│       └── external/             # External service adapters
│           └── email_adapter.ex
├── shared/                       # Shared infrastructure (optional)
│   ├── repo.ex                   # Ecto.Repo (top-level boundary)
│   └── mailer.ex                 # Swoosh.Mailer (top-level boundary)
└── {app}.ex                      # App entry point
```

## Boundary Definitions

### Context Boundary (Public API)

```elixir
# lib/accounts/accounts.ex
defmodule MyApp.Accounts do
  @moduledoc """
  Public API for the Accounts context.
  
  External code should ONLY interact with this module, never
  directly with Domain, Application, or Infrastructure.
  """
  
  use Boundary,
    deps: [
      # Other contexts this one depends on
      MyApp.Shared.Repo,
      MyApp.Shared.Mailer
    ],
    exports: [
      # Only export what external code needs
      Domain.Entities.User,
      Domain.Entities.Session
    ]
  
  # Delegate to use cases for write operations
  defdelegate register_user(params), to: Application.UseCases.RegisterUser, as: :execute
  
  # Simple reads can query directly
  def get_user(id), do: ...
end
```

### Domain Layer Boundary

```elixir
# lib/accounts/domain.ex
defmodule MyApp.Accounts.Domain do
  @moduledoc """
  Domain layer for the Accounts context.
  
  Contains:
  - Entities: Pure structs representing domain concepts
  - Policies: Business rules as pure functions
  - Services: Domain logic as pure functions
  
  ## Dependency Rule
  
  The Domain layer has NO dependencies. It cannot import:
  - Application layer (use cases)
  - Infrastructure layer (repos, schemas)
  - External libraries (Ecto, Phoenix, etc.)
  - Other contexts
  """
  
  use Boundary,
    deps: [],
    exports: [
      Entities.User,
      Entities.Session,
      Policies.AuthenticationPolicy,
      Services.TokenBuilder
    ]
end
```

### Application Layer Boundary

```elixir
# lib/accounts/application.ex
defmodule MyApp.Accounts.Application do
  @moduledoc """
  Application layer for the Accounts context.
  
  Contains:
  - Use Cases: Orchestrate domain logic and infrastructure
  - Services: Application-specific services
  
  ## Dependency Rule
  
  The Application layer may only depend on:
  - Domain layer (same context)
  
  It cannot import:
  - Infrastructure layer (repos, schemas)
  - Other contexts directly (use dependency injection)
  """
  
  use Boundary,
    deps: [MyApp.Accounts.Domain],
    exports: [
      UseCases.RegisterUser,
      UseCases.AuthenticateUser,
      Services.PasswordService
    ]
end
```

### Infrastructure Layer Boundary

```elixir
# lib/accounts/infrastructure.ex
defmodule MyApp.Accounts.Infrastructure do
  @moduledoc """
  Infrastructure layer for the Accounts context.
  
  Contains:
  - Schemas: Ecto schemas (database representation)
  - Repos: Repository pattern implementations
  - Queries: Ecto query builders
  - External: Adapters for external services
  
  ## Dependency Rule
  
  The Infrastructure layer may depend on:
  - Domain layer (for entities/policies)
  - Application layer (for behaviours to implement)
  
  It can use external libraries (Ecto, HTTP clients, etc.)
  """
  
  use Boundary,
    deps: [MyApp.Accounts.Domain, MyApp.Accounts.Application],
    exports: [
      Schemas.UserSchema,
      Repos.UserRepo
    ]
end
```

### Shared Infrastructure Boundaries

```elixir
# lib/shared/repo.ex
defmodule MyApp.Shared.Repo do
  @moduledoc "Shared Ecto repository."
  
  use Boundary, top_level?: true, deps: []
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
end

# lib/shared/mailer.ex
defmodule MyApp.Shared.Mailer do
  @moduledoc "Shared email service."
  
  use Boundary, top_level?: true, deps: []
  use Swoosh.Mailer, otp_app: :my_app
end
```

## Dependency Rules Summary

```
                    ┌─────────────────────────────────────┐
                    │         Context Boundary            │
                    │  (Public API - exports to outside)  │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Within Context                          │
│                                                                 │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│   │   Domain    │◄───│ Application │◄───│Infrastructure│        │
│   │  deps: []   │    │deps:[Domain]│    │deps:[D, App]│        │
│   └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                 │
│   Entities          Use Cases           Schemas                │
│   Events            Services            Repos                  │
│   Policies                              Subscribers            │
│   Domain Services                       External Adapters      │
└─────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │       Shared Infrastructure         │
                    │   (Repo, Mailer - top_level: true)  │
                    └─────────────────────────────────────┘
```

## Enforcement

### Compile-Time (Boundary Library)

The Boundary library enforces these rules at compile time. If code violates
a dependency rule, compilation fails with a clear error message.

### Static Analysis (Credo Checks)

Additional Credo checks provide defense-in-depth:
- `EX7003`: Verifies Boundary is configured
- `EX7004`: Verifies boundary deps follow CA rules
- `NoRepoInDomain`: Detects Repo imports in domain
- `NoEctoInDomainLayer`: Detects Ecto usage in domain
- `NoPubSubInContexts`: Prevents direct `Phoenix.PubSub.broadcast` in context modules (use `EventBus.emit` instead)
- `NoBroadcastInTransaction`: Prevents PubSub broadcasts inside database transaction blocks
- ... (30+ architectural checks)

## Creating a New Context

1. Create the directory structure:
   ```bash
   mkdir -p lib/{context}/{domain,application,infrastructure}/{entities,events,policies,services,use_cases,schemas,repos,queries,subscribers}
   ```

2. Create the boundary files:
   - `lib/{context}/{context}.ex` - Public API
   - `lib/{context}/domain.ex` - Domain boundary
   - `lib/{context}/application.ex` - Application boundary  
   - `lib/{context}/infrastructure.ex` - Infrastructure boundary

3. Add context to the app's boundary deps if needed

4. Run `mix compile` to verify boundaries
