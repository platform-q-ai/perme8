# Feature: Webhooks Module

## Overview

Add a webhooks module to support outbound webhook subscriptions (event-driven HTTP POST dispatches with HMAC-SHA256 signing and exponential backoff retries) and inbound webhook reception (signature verification, routing, and audit logging). Delivered as two new umbrella apps: `apps/webhooks/` (domain, application, infrastructure) and `apps/webhooks_api/` (Phoenix API controllers, JSON views, plugs, router).

## UI Strategy

- **LiveView coverage**: 0% -- this is a pure API feature with no browser UI
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context**: `Webhooks` (new umbrella app `apps/webhooks/`)
- **API interface**: `WebhooksApi` (new umbrella app `apps/webhooks_api/`)
- **Dependencies**:
  - `Identity` -- API key verification, user lookup, workspace membership
  - `Jarga.Workspaces` -- workspace and member resolution via `get_workspace_and_member_by_slug/2`
  - `Perme8.Events` -- EventBus subscription (outbound handler), EventHandler behaviour, DomainEvent macro
  - `Identity.Repo` / `Jarga.Repo` -- shared Postgres database
- **Exported schemas**: `Webhooks.Domain.Entities.Subscription`, `Webhooks.Infrastructure.Schemas.SubscriptionSchema`
- **New context needed?**: Yes -- webhooks is a distinct bounded context with its own aggregate lifecycle (subscriptions, deliveries, inbound logs)

## Existing Domain Events Subscribed To

The outbound webhook EventHandler subscribes to these existing event topics:
- `"events:projects"` -- ProjectCreated, ProjectUpdated, ProjectDeleted, ProjectArchived
- `"events:documents"` -- DocumentCreated, DocumentDeleted, DocumentTitleChanged, DocumentVisibilityChanged, DocumentPinnedChanged

---

## Phase 1: Domain Layer (pure business logic, no I/O)

> **App**: `apps/webhooks/`
> **Test case**: `use ExUnit.Case, async: true` (pure, no DB)

### 1.1 Subscription Entity

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/domain/entities/subscription_test.exs`
  - Tests:
    - `new/1` creates a struct with all fields (id, url, secret, event_types, is_active, workspace_id, created_by_id, inserted_at, updated_at)
    - `from_schema/1` converts an infrastructure schema map to a domain entity
    - Default `is_active` is `true`
    - `active?/1` returns correct boolean
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/domain/entities/subscription.ex`
  - Pure `defstruct` with `@type t` spec
  - Functions: `new/1`, `from_schema/1`, `active?/1`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.2 Delivery Entity

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/domain/entities/delivery_test.exs`
  - Tests:
    - `new/1` creates struct (id, subscription_id, event_type, payload, status, response_code, attempts, next_retry_at, inserted_at, updated_at)
    - `from_schema/1` converts schema to domain entity
    - `success?/1`, `failed?/1`, `pending?/1` status predicates
    - `max_retries_reached?/1` returns true when attempts >= 5
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/domain/entities/delivery.ex`
  - Pure `defstruct`, status predicates, `@max_retries 5`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.3 InboundLog Entity

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/domain/entities/inbound_log_test.exs`
  - Tests:
    - `new/1` creates struct (id, workspace_id, event_type, payload, source_ip, signature_valid, received_at)
    - `from_schema/1` converts schema to domain entity
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/domain/entities/inbound_log.ex`
  - Pure `defstruct`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.4 InboundWebhookConfig Entity

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/domain/entities/inbound_webhook_config_test.exs`
  - Tests:
    - `new/1` creates struct (id, workspace_id, secret, is_active, inserted_at, updated_at)
    - `from_schema/1` converts schema to domain entity
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/domain/entities/inbound_webhook_config.ex`
  - Pure `defstruct`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.5 WebhookAuthorizationPolicy

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/domain/policies/webhook_authorization_policy_test.exs`
  - Tests:
    - `:owner` can manage webhooks (`can_manage_webhooks?/1` returns true)
    - `:admin` can manage webhooks (returns true)
    - `:member` cannot manage webhooks (returns false)
    - `:guest` cannot manage webhooks (returns false)
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/domain/policies/webhook_authorization_policy.ex`
  - Pure function: `can_manage_webhooks?(role)` -- returns true for `:owner` and `:admin`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.6 HmacPolicy (pure signature computation)

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/domain/policies/hmac_policy_test.exs`
  - Tests:
    - `compute_signature/2` returns HMAC-SHA256 hex digest of (secret, payload)
    - `valid_signature?/3` returns true when signature matches
    - `valid_signature?/3` returns false when signature does not match
    - `valid_signature?/3` returns false for nil or empty signature
    - Works with binary payload (raw JSON string)
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/domain/policies/hmac_policy.ex`
  - `:crypto.mac(:hmac, :sha256, secret, payload)` wrapped as pure functions
  - `compute_signature/2`, `valid_signature?/3`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.7 RetryPolicy (pure backoff computation)

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/domain/policies/retry_policy_test.exs`
  - Tests:
    - `should_retry?/1` returns true for attempts 0..4, false for 5+
    - `next_retry_delay_seconds/1` returns exponential backoff (2^attempt * base)
    - `max_retries/0` returns 5
    - Backoff values are within expected ranges (base * 2^attempt)
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/domain/policies/retry_policy.ex`
  - Pure functions: `should_retry?/1`, `next_retry_delay_seconds/1`, `max_retries/0`
  - Exponential backoff: base 15s, formula: `15 * 2^attempt` (15s, 30s, 60s, 120s, 240s)
- [ ] ⏸ **REFACTOR**: Clean up

### 1.8 SecretGeneratorPolicy

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/domain/policies/secret_generator_policy_test.exs`
  - Tests:
    - `generate/0` returns a string of at least 32 characters
    - `generate/0` returns unique values on repeated calls
    - `sufficient_length?/1` returns true for strings >= 32 chars, false otherwise
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/domain/policies/secret_generator_policy.ex`
  - Uses `:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)`
  - `generate/0`, `sufficient_length?/1`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.9 Domain Boundary Module

- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/domain.ex`
  ```elixir
  defmodule Webhooks.Domain do
    use Boundary,
      top_level?: true,
      deps: [],
      exports: [
        Entities.Subscription,
        Entities.Delivery,
        Entities.InboundLog,
        Entities.InboundWebhookConfig,
        Policies.WebhookAuthorizationPolicy,
        Policies.HmacPolicy,
        Policies.RetryPolicy,
        Policies.SecretGeneratorPolicy
      ]
  end
  ```

### Phase 1 Validation

- [ ] ⏸ All domain tests pass with `use ExUnit.Case, async: true` (milliseconds, no I/O)
- [ ] ⏸ Domain has ZERO deps in boundary config
- [ ] ⏸ No Ecto, Phoenix, or Repo references in domain layer

---

## Phase 2: Application Layer (use cases + behaviours)

> **App**: `apps/webhooks/`
> **Test case**: `use Jarga.DataCase, async: false` with `TestEventBus` for DI

### 2.1 UseCase Behaviour

- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/application/use_cases/use_case.ex`
  - `@callback execute(params :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}`
  - Follows `Jarga.Projects.Application.UseCases.UseCase` pattern exactly

### 2.2 Repository Behaviours

- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/application/behaviours/subscription_repository_behaviour.ex`
  - Callbacks: `insert/2`, `update/3`, `delete/2`, `get_by_id/3`, `list_for_workspace/3`
- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/application/behaviours/delivery_repository_behaviour.ex`
  - Callbacks: `insert/2`, `get_by_id/3`, `list_for_subscription/3`, `update_status/4`
- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/application/behaviours/inbound_log_repository_behaviour.ex`
  - Callbacks: `insert/2`, `list_for_workspace/3`
- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/application/behaviours/inbound_webhook_config_repository_behaviour.ex`
  - Callbacks: `get_by_workspace_id/2`
- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/application/behaviours/http_dispatcher_behaviour.ex`
  - Callbacks: `dispatch/3` (url, payload, headers -> {:ok, status_code, body} | {:error, reason})

### 2.3 CreateSubscription Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/create_subscription_test.exs`
  - Tests (with Mox mocks for repository and workspace resolution):
    - Successfully creates subscription with auto-generated secret
    - Returns `{:ok, subscription}` with secret included
    - Returns `{:error, :forbidden}` when member role is `:member` or `:guest`
    - Returns `{:error, changeset}` for invalid attrs (missing url)
    - Returns `{:error, :workspace_not_found}` for unknown workspace
    - Secret is >= 32 characters
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/create_subscription.ex`
  - `@behaviour UseCase`
  - DI: `subscription_repository`, `event_bus`
  - Steps: resolve workspace + member via injected fn -> authorize via `WebhookAuthorizationPolicy.can_manage_webhooks?(role)` -> generate secret -> repo.insert -> return `{:ok, subscription_with_secret}`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.4 ListSubscriptions Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/list_subscriptions_test.exs`
  - Tests:
    - Returns list of subscriptions for workspace (WITHOUT secrets)
    - Returns `{:error, :forbidden}` for non-admin roles
    - Returns empty list for workspace with no subscriptions
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/list_subscriptions.ex`
  - Authorize -> repo.list_for_workspace -> strip secrets from results
- [ ] ⏸ **REFACTOR**: Clean up

### 2.5 GetSubscription Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/get_subscription_test.exs`
  - Tests:
    - Returns subscription by ID (WITHOUT secret)
    - Returns `{:error, :not_found}` for missing subscription
    - Returns `{:error, :forbidden}` for non-admin roles
    - Verifies subscription belongs to the given workspace
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/get_subscription.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.6 UpdateSubscription Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/update_subscription_test.exs`
  - Tests:
    - Updates url, event_types, is_active
    - Returns `{:error, :not_found}` for missing subscription
    - Returns `{:error, :forbidden}` for non-admin roles
    - Does NOT return secret in response
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/update_subscription.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.7 DeleteSubscription Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/delete_subscription_test.exs`
  - Tests:
    - Deletes subscription successfully
    - Returns `{:error, :not_found}` for missing subscription
    - Returns `{:error, :forbidden}` for non-admin roles
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/delete_subscription.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.8 ListDeliveries Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/list_deliveries_test.exs`
  - Tests:
    - Returns list of deliveries for a subscription
    - Returns `{:error, :not_found}` if subscription not found
    - Returns `{:error, :forbidden}` for non-admin roles
    - Returns empty list when no deliveries exist
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/list_deliveries.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.9 GetDelivery Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/get_delivery_test.exs`
  - Tests:
    - Returns delivery by ID with full details (payload, attempts, next_retry_at, status)
    - Returns `{:error, :not_found}` for missing delivery
    - Returns `{:error, :forbidden}` for non-admin roles
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/get_delivery.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.10 DispatchWebhook Use Case (outbound delivery)

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/dispatch_webhook_test.exs`
  - Tests (mocked HTTP dispatcher and repo):
    - Creates delivery record, dispatches HTTP POST with HMAC signature
    - Records success (status "success", response_code 200)
    - Records failure (status "pending", response_code 500, schedules retry)
    - After max retries, sets status to "failed" with no next_retry_at
    - Skips inactive subscriptions
    - Only dispatches to subscriptions matching event_type filter
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/dispatch_webhook.ex`
  - DI: `http_dispatcher`, `subscription_repository`, `delivery_repository`
  - Steps: find matching active subscriptions -> for each, build payload JSON -> compute HMAC-SHA256 signature -> dispatch HTTP POST -> record delivery result -> schedule retry if needed
- [ ] ⏸ **REFACTOR**: Clean up

### 2.11 ReceiveInboundWebhook Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/receive_inbound_webhook_test.exs`
  - Tests:
    - Valid signature: records inbound log, returns `{:ok, log}`
    - Invalid signature: records log with `signature_valid: false`, returns `{:error, :invalid_signature}`
    - Missing signature header: returns `{:error, :missing_signature}`
    - No inbound config for workspace: returns `{:error, :not_configured}`
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/receive_inbound_webhook.ex`
  - DI: `inbound_webhook_config_repository`, `inbound_log_repository`
  - Steps: get config for workspace -> verify HMAC signature -> record inbound log -> return result
- [ ] ⏸ **REFACTOR**: Clean up

### 2.12 ListInboundLogs Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/list_inbound_logs_test.exs`
  - Tests:
    - Returns list of inbound logs for workspace
    - Returns `{:error, :forbidden}` for non-admin roles
    - Returns empty list when no logs exist
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/list_inbound_logs.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.13 RetryDelivery Use Case

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/application/use_cases/retry_delivery_test.exs`
  - Tests:
    - Retries a pending delivery: re-dispatches, updates attempts count
    - On success: sets status to "success", clears next_retry_at
    - On failure with retries remaining: increments attempts, sets next_retry_at
    - On failure with max retries: sets status to "failed", clears next_retry_at
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/application/use_cases/retry_delivery.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.14 Application Boundary Module

- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/application.ex`
  ```elixir
  defmodule Webhooks.Application do
    use Boundary,
      top_level?: true,
      deps: [
        Webhooks.Domain,
        Perme8.Events,
        Identity,
        Jarga.Workspaces
      ],
      exports: [
        UseCases.UseCase,
        UseCases.CreateSubscription,
        UseCases.ListSubscriptions,
        UseCases.GetSubscription,
        UseCases.UpdateSubscription,
        UseCases.DeleteSubscription,
        UseCases.ListDeliveries,
        UseCases.GetDelivery,
        UseCases.DispatchWebhook,
        UseCases.ReceiveInboundWebhook,
        UseCases.ListInboundLogs,
        UseCases.RetryDelivery,
        Behaviours.SubscriptionRepositoryBehaviour,
        Behaviours.DeliveryRepositoryBehaviour,
        Behaviours.InboundLogRepositoryBehaviour,
        Behaviours.InboundWebhookConfigRepositoryBehaviour,
        Behaviours.HttpDispatcherBehaviour
      ]
  end
  ```

### Phase 2 Validation

- [ ] ⏸ All application tests pass with mocked dependencies
- [ ] ⏸ Application layer depends only on Domain + cross-context public APIs
- [ ] ⏸ All use cases follow `@behaviour UseCase` pattern
- [ ] ⏸ All DI uses `Keyword.get(opts, :key, @default)` pattern

---

## Phase 3: Infrastructure Layer (schemas, migrations, repos, services)

> **App**: `apps/webhooks/`
> **Test case**: `use Jarga.DataCase` for DB tests, `use ExUnit.Case` for pure service tests
> **HTTP mocking**: `Bypass` for external HTTP endpoint simulation

### 3.1 Database Migrations

All migrations go in `apps/jarga/priv/repo/migrations/` (shared DB via Jarga.Repo).

- [ ] ⏸ **GREEN**: Create `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_create_webhook_subscriptions.exs`
  ```elixir
  create table(:webhook_subscriptions, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :url, :string, null: false
    add :secret, :string, null: false
    add :event_types, {:array, :string}, null: false, default: []
    add :is_active, :boolean, null: false, default: true
    add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
    add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    timestamps(type: :utc_datetime)
  end
  create index(:webhook_subscriptions, [:workspace_id])
  create index(:webhook_subscriptions, [:workspace_id, :is_active])
  ```

- [ ] ⏸ **GREEN**: Create `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_create_webhook_deliveries.exs`
  ```elixir
  create table(:webhook_deliveries, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :subscription_id, references(:webhook_subscriptions, type: :binary_id, on_delete: :delete_all), null: false
    add :event_type, :string, null: false
    add :payload, :map, null: false, default: %{}
    add :status, :string, null: false, default: "pending"  # pending, success, failed
    add :response_code, :integer
    add :response_body, :text
    add :attempts, :integer, null: false, default: 0
    add :next_retry_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
  create index(:webhook_deliveries, [:subscription_id])
  create index(:webhook_deliveries, [:status, :next_retry_at])
  ```

- [ ] ⏸ **GREEN**: Create `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_create_inbound_webhook_configs.exs`
  ```elixir
  create table(:inbound_webhook_configs, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
    add :secret, :string, null: false
    add :is_active, :boolean, null: false, default: true
    timestamps(type: :utc_datetime)
  end
  create unique_index(:inbound_webhook_configs, [:workspace_id])
  ```

- [ ] ⏸ **GREEN**: Create `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_create_inbound_webhook_logs.exs`
  ```elixir
  create table(:inbound_webhook_logs, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
    add :event_type, :string
    add :payload, :map, default: %{}
    add :source_ip, :string
    add :signature_valid, :boolean, null: false, default: false
    add :received_at, :utc_datetime, null: false
    timestamps(type: :utc_datetime)
  end
  create index(:inbound_webhook_logs, [:workspace_id])
  create index(:inbound_webhook_logs, [:workspace_id, :received_at])
  ```

### 3.2 SubscriptionSchema

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/schemas/subscription_schema_test.exs`
  - Tests:
    - Valid changeset with all required fields (url, secret, event_types, workspace_id, created_by_id)
    - Requires url
    - Requires secret
    - Requires workspace_id
    - Validates url format (must start with https://)
    - Casts event_types as array of strings
    - Defaults is_active to true
    - Foreign key constraint on workspace_id
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/schemas/subscription_schema.ex`
  - `@primary_key {:id, :binary_id, autogenerate: true}`, `@foreign_key_type :binary_id`
  - Schema `"webhook_subscriptions"`, changeset with validations
- [ ] ⏸ **REFACTOR**: Clean up

### 3.3 DeliverySchema

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/schemas/delivery_schema_test.exs`
  - Tests:
    - Valid changeset with required fields
    - Requires subscription_id, event_type
    - Defaults status to "pending", attempts to 0
    - Validates status is one of: "pending", "success", "failed"
    - Casts payload as map
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/schemas/delivery_schema.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.4 InboundWebhookConfigSchema

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/schemas/inbound_webhook_config_schema_test.exs`
  - Tests:
    - Valid changeset with workspace_id and secret
    - Requires workspace_id and secret
    - Defaults is_active to true
    - Unique constraint on workspace_id
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/schemas/inbound_webhook_config_schema.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.5 InboundLogSchema

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/schemas/inbound_log_schema_test.exs`
  - Tests:
    - Valid changeset with required fields
    - Requires workspace_id and received_at
    - Casts payload as map
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/schemas/inbound_log_schema.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.6 Subscription Queries

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/queries/subscription_queries_test.exs`
  - Tests:
    - `for_workspace/2` filters by workspace_id
    - `active/1` filters only active subscriptions
    - `by_id/2` finds by ID
    - `by_id_and_workspace/3` finds by ID within specific workspace
    - `matching_event_type/2` filters subscriptions whose event_types array contains the given type
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/queries/subscription_queries.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.7 Delivery Queries

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/queries/delivery_queries_test.exs`
  - Tests:
    - `for_subscription/2` filters by subscription_id
    - `by_id/2` finds by ID
    - `pending_retries/1` finds deliveries with status "pending" and next_retry_at <= now
    - `ordered/1` orders by inserted_at desc
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/queries/delivery_queries.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.8 InboundLog Queries

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/queries/inbound_log_queries_test.exs`
  - Tests:
    - `for_workspace/2` filters by workspace_id
    - `ordered/1` orders by received_at desc
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/queries/inbound_log_queries.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.9 SubscriptionRepository

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/repositories/subscription_repository_test.exs`
  - Tests:
    - `insert/2` creates and returns domain entity
    - `update/3` updates and returns domain entity
    - `delete/2` removes record
    - `get_by_id/3` returns domain entity or nil
    - `list_for_workspace/3` returns list of domain entities
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/repositories/subscription_repository.ex`
  - `@behaviour SubscriptionRepositoryBehaviour`
  - Uses `Identity.Repo`, converts to/from domain entities
- [ ] ⏸ **REFACTOR**: Clean up

### 3.10 DeliveryRepository

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/repositories/delivery_repository_test.exs`
  - Tests:
    - `insert/2` creates delivery record
    - `get_by_id/3` returns delivery or nil
    - `list_for_subscription/3` returns deliveries for a subscription
    - `update_status/4` updates status, response_code, attempts, next_retry_at
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/repositories/delivery_repository.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.11 InboundLogRepository

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/repositories/inbound_log_repository_test.exs`
  - Tests:
    - `insert/2` creates log record
    - `list_for_workspace/3` returns logs ordered by received_at desc
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/repositories/inbound_log_repository.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.12 InboundWebhookConfigRepository

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/repositories/inbound_webhook_config_repository_test.exs`
  - Tests:
    - `get_by_workspace_id/2` returns config or nil
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/repositories/inbound_webhook_config_repository.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.13 HttpDispatcher Service

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/services/http_dispatcher_test.exs`
  - Tests (using `Bypass`):
    - Dispatches POST request with JSON payload
    - Includes `X-Webhook-Signature` header with HMAC-SHA256 signature
    - Includes `Content-Type: application/json` header
    - Returns `{:ok, status_code, body}` on success
    - Returns `{:error, reason}` on connection failure
    - Returns `{:error, :timeout}` on timeout
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/services/http_dispatcher.ex`
  - `@behaviour HttpDispatcherBehaviour`
  - Uses `Req` library for HTTP POST
  - `dispatch(url, payload, headers)` function
- [ ] ⏸ **REFACTOR**: Clean up

### 3.14 OutboundWebhookHandler (EventHandler subscriber)

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/subscribers/outbound_webhook_handler_test.exs`
  - Tests:
    - `subscriptions/0` returns `["events:projects", "events:documents"]`
    - `handle_event/1` with ProjectCreated dispatches to matching subscriptions
    - `handle_event/1` with DocumentCreated dispatches to matching subscriptions
    - `handle_event/1` with unmatched event type does nothing (returns :ok)
    - Constructs correct payload shape: `{event_type, aggregate_id, workspace_id, timestamp, data}`
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/subscribers/outbound_webhook_handler.ex`
  - `use Perme8.Events.EventHandler`
  - Subscribes to `["events:projects", "events:documents"]`
  - Pattern-matches on event structs, delegates to `DispatchWebhook` use case
- [ ] ⏸ **REFACTOR**: Clean up

### 3.15 RetryWorker (GenServer for scheduled retries)

- [ ] ⏸ **RED**: Write test `apps/webhooks/test/webhooks/infrastructure/workers/retry_worker_test.exs`
  - Tests:
    - Worker starts and schedules periodic check
    - Polls for pending retries and dispatches `RetryDelivery` use case
    - Only processes deliveries with `next_retry_at <= now`
- [ ] ⏸ **GREEN**: Implement `apps/webhooks/lib/webhooks/infrastructure/workers/retry_worker.ex`
  - GenServer with `Process.send_after` for periodic polling (every 30 seconds)
  - Queries for pending deliveries, calls `RetryDelivery.execute/2` for each
- [ ] ⏸ **REFACTOR**: Clean up

### 3.16 Infrastructure Boundary Module

- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks/infrastructure.ex`
  ```elixir
  defmodule Webhooks.Infrastructure do
    use Boundary,
      top_level?: true,
      deps: [
        Webhooks.Domain,
        Webhooks.Application,
        Identity,
        Identity.Repo,
        Jarga.Repo,
        Perme8.Events
      ],
      exports: [
        Schemas.SubscriptionSchema,
        Schemas.DeliverySchema,
        Schemas.InboundLogSchema,
        Schemas.InboundWebhookConfigSchema,
        Repositories.SubscriptionRepository,
        Repositories.DeliveryRepository,
        Repositories.InboundLogRepository,
        Repositories.InboundWebhookConfigRepository,
        Queries.SubscriptionQueries,
        Queries.DeliveryQueries,
        Queries.InboundLogQueries,
        Services.HttpDispatcher,
        Subscribers.OutboundWebhookHandler,
        Workers.RetryWorker
      ]
  end
  ```

### Phase 3 Validation

- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ Migrations run cleanly (`mix ecto.migrate`)
- [ ] ⏸ Bypass-based HTTP tests confirm dispatcher behaviour
- [ ] ⏸ Repositories correctly convert between schemas and domain entities
- [ ] ⏸ No boundary violations

---

## Phase 4: Context Facade + webhooks_api App (controllers, JSON views, plugs, router)

> **Context facade**: `apps/webhooks/lib/webhooks.ex`
> **API app**: `apps/webhooks_api/`

### 4.1 Webhooks Context Facade

- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks.ex`
  ```elixir
  defmodule Webhooks do
    use Boundary,
      top_level?: true,
      deps: [
        Identity,
        Identity.Repo,
        Jarga.Repo,
        Jarga.Workspaces,
        Webhooks.Domain,
        Webhooks.Application,
        Webhooks.Infrastructure,
        Perme8.Events
      ],
      exports: [
        {Domain.Entities.Subscription, []},
        {Domain.Entities.Delivery, []},
        {Domain.Entities.InboundLog, []},
        {Infrastructure.Schemas.SubscriptionSchema, []}
      ]

    # --- Outbound Subscription CRUD ---
    def create_subscription(user, api_key, workspace_slug, attrs, opts \\ [])
    def list_subscriptions(user, api_key, workspace_slug, opts \\ [])
    def get_subscription(user, api_key, workspace_slug, subscription_id, opts \\ [])
    def update_subscription(user, api_key, workspace_slug, subscription_id, attrs, opts \\ [])
    def delete_subscription(user, api_key, workspace_slug, subscription_id, opts \\ [])

    # --- Delivery Logs ---
    def list_deliveries(user, api_key, workspace_slug, subscription_id, opts \\ [])
    def get_delivery(user, api_key, workspace_slug, subscription_id, delivery_id, opts \\ [])

    # --- Inbound Webhooks ---
    def receive_inbound_webhook(workspace_slug, raw_body, signature, source_ip, opts \\ [])

    # --- Inbound Audit Logs ---
    def list_inbound_logs(user, api_key, workspace_slug, opts \\ [])
  end
  ```
  - Each function wires DI defaults and delegates to the appropriate use case
  - Resolves workspace + member via `Jarga.Workspaces.get_workspace_and_member_by_slug/2`
  - Checks API key scope via injected `ApiKeyScope.includes?/2` pattern (similar to JargaApi.Accounts)

### 4.2 WebhooksApi App Module

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api.ex`
  - Follows `JargaApi` pattern: `use Boundary`, `def router`, `def controller`, `def verified_routes`
  - Boundary deps: `[Webhooks, Identity, Jarga.Workspaces, WebhooksApi.Accounts]`
  - Exports: `[Endpoint]`

### 4.3 WebhooksApi Endpoint

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/endpoint.ex`
  - Follows `JargaApi.Endpoint` pattern
  - `use Phoenix.Endpoint, otp_app: :webhooks_api`
  - Ecto sandbox for tests (conditional, using `:jarga` sandbox config)
  - **Critical**: Configure `Plug.Parsers` with `body_reader: {WebhooksApi.Plugs.CacheRawBody, :read_body, []}` to preserve raw body for HMAC verification on inbound webhook routes
  - Plug `WebhooksApi.Router`

### 4.4 CacheRawBody Plug

- [ ] ⏸ **RED**: Write test `apps/webhooks_api/test/webhooks_api/plugs/cache_raw_body_test.exs`
  - Tests:
    - Stores raw body in `conn.assigns[:raw_body]`
    - Raw body is preserved even after JSON parsing
- [ ] ⏸ **GREEN**: Implement `apps/webhooks_api/lib/webhooks_api/plugs/cache_raw_body.ex`
  - Custom `read_body/2` that caches the raw bytes in conn private
- [ ] ⏸ **REFACTOR**: Clean up

### 4.5 SecurityHeadersPlug

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/plugs/security_headers_plug.ex`
  - Copy from `JargaApi.Plugs.SecurityHeadersPlug` (identical security headers)

### 4.6 ApiAuthPlug (reuse pattern)

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/plugs/api_auth_plug.ex`
  - Copy from `JargaApi.Plugs.ApiAuthPlug` pattern (identical auth flow)
  - Uses `Identity.verify_api_key/1` and `Identity.get_user/1`

### 4.7 WebhooksApi Router

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/router.ex`
  ```elixir
  defmodule WebhooksApi.Router do
    use WebhooksApi, :router

    pipeline :api_base do
      plug :accepts, ["json"]
      plug WebhooksApi.Plugs.SecurityHeadersPlug
    end

    pipeline :api_authenticated do
      plug WebhooksApi.Plugs.ApiAuthPlug
    end

    # Authenticated outbound webhook management routes
    scope "/api", WebhooksApi do
      pipe_through [:api_base, :api_authenticated]

      # Subscription CRUD
      get "/workspaces/:workspace_slug/webhooks", SubscriptionController, :index
      post "/workspaces/:workspace_slug/webhooks", SubscriptionController, :create
      get "/workspaces/:workspace_slug/webhooks/:id", SubscriptionController, :show
      patch "/workspaces/:workspace_slug/webhooks/:id", SubscriptionController, :update
      delete "/workspaces/:workspace_slug/webhooks/:id", SubscriptionController, :delete

      # Delivery logs
      get "/workspaces/:workspace_slug/webhooks/:subscription_id/deliveries", DeliveryController, :index
      get "/workspaces/:workspace_slug/webhooks/:subscription_id/deliveries/:id", DeliveryController, :show

      # Inbound webhook audit logs (authenticated)
      get "/workspaces/:workspace_slug/webhooks/inbound/logs", InboundLogController, :index
    end

    # Inbound webhook receiver (HMAC signature auth, NOT Bearer token)
    scope "/api", WebhooksApi do
      pipe_through [:api_base]

      post "/workspaces/:workspace_slug/webhooks/inbound", InboundWebhookController, :receive
    end
  end
  ```

### 4.8 SubscriptionController

- [ ] ⏸ **RED**: Write test `apps/webhooks_api/test/webhooks_api/controllers/subscription_controller_test.exs`
  - Tests:
    - `POST /api/workspaces/:slug/webhooks` -- 201 with secret, 422 for invalid, 403 for member, 401 for missing auth
    - `GET /api/workspaces/:slug/webhooks` -- 200 with list (no secrets), 403 for member
    - `GET /api/workspaces/:slug/webhooks/:id` -- 200 without secret, 404 for missing, 403 for member
    - `PATCH /api/workspaces/:slug/webhooks/:id` -- 200 with updated fields, 404, 403
    - `DELETE /api/workspaces/:slug/webhooks/:id` -- 200/204, 404, 403
- [ ] ⏸ **GREEN**: Implement `apps/webhooks_api/lib/webhooks_api/controllers/subscription_controller.ex`
  - `use WebhooksApi, :controller`
  - Actions: `create/2`, `index/2`, `show/2`, `update/2`, `delete/2`
  - Each action: extracts user/api_key from conn.assigns, calls `Webhooks` facade, renders JSON
- [ ] ⏸ **REFACTOR**: Clean up

### 4.9 SubscriptionApiJSON

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/controllers/subscription_api_json.ex`
  - `created/1` -- includes secret (only on 201 creation)
  - `show/1` -- excludes secret
  - `index/1` -- list without secrets
  - `error/1`, `validation_error/1` -- follows `JargaApi.ProjectApiJSON` pattern

### 4.10 DeliveryController

- [ ] ⏸ **RED**: Write test `apps/webhooks_api/test/webhooks_api/controllers/delivery_controller_test.exs`
  - Tests:
    - `GET /api/workspaces/:slug/webhooks/:sub_id/deliveries` -- 200 with list, 403 for member
    - `GET /api/workspaces/:slug/webhooks/:sub_id/deliveries/:id` -- 200 with full delivery details, 404
- [ ] ⏸ **GREEN**: Implement `apps/webhooks_api/lib/webhooks_api/controllers/delivery_controller.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 4.11 DeliveryApiJSON

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/controllers/delivery_api_json.ex`
  - `index/1` -- list with basic fields (id, event_type, status, response_code, inserted_at)
  - `show/1` -- full delivery details (payload, attempts, next_retry_at)

### 4.12 InboundWebhookController

- [ ] ⏸ **RED**: Write test `apps/webhooks_api/test/webhooks_api/controllers/inbound_webhook_controller_test.exs`
  - Tests:
    - `POST /api/workspaces/:slug/webhooks/inbound` with valid signature -- 200
    - Invalid signature -- 401
    - Missing signature -- 401
    - Malformed JSON body -- 400
- [ ] ⏸ **GREEN**: Implement `apps/webhooks_api/lib/webhooks_api/controllers/inbound_webhook_controller.ex`
  - Extracts `X-Webhook-Signature` header, raw body from conn
  - Calls `Webhooks.receive_inbound_webhook/4`
  - Returns appropriate status codes
- [ ] ⏸ **REFACTOR**: Clean up

### 4.13 InboundWebhookApiJSON

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/controllers/inbound_webhook_api_json.ex`
  - `received/1` -- acknowledgement response
  - `error/1` -- error response

### 4.14 InboundLogController

- [ ] ⏸ **RED**: Write test `apps/webhooks_api/test/webhooks_api/controllers/inbound_log_controller_test.exs`
  - Tests:
    - `GET /api/workspaces/:slug/webhooks/inbound/logs` -- 200 with list, 403 for member
- [ ] ⏸ **GREEN**: Implement `apps/webhooks_api/lib/webhooks_api/controllers/inbound_log_controller.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 4.15 InboundLogApiJSON

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/controllers/inbound_log_api_json.ex`
  - `index/1` -- list with event_type, payload, signature_valid, received_at

### 4.16 WebhooksApi.Application (OTP supervisor)

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/application.ex`
  - Starts `WebhooksApi.Endpoint` under supervision
  - Follows `JargaApi.Application` pattern

### 4.17 ErrorJSON

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/lib/webhooks_api/error_json.ex`
  - Standard Phoenix error JSON module

### 4.18 WebhooksApi ConnCase (test support)

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/test/support/conn_case.ex`
  - Follows `JargaApi.ConnCase` pattern
  - `@endpoint WebhooksApi.Endpoint`
  - Sets up sandbox via `Jarga.DataCase.setup_sandbox/1`

### Phase 4 Validation

- [ ] ⏸ All controller tests pass
- [ ] ⏸ Router compiles without errors
- [ ] ⏸ Secret is returned ONLY on creation (201), never on GET/LIST/UPDATE
- [ ] ⏸ Non-admin users receive 403 on all management endpoints
- [ ] ⏸ Inbound webhook endpoint does NOT require Bearer token auth
- [ ] ⏸ No boundary violations

---

## Phase 5: Seed Data and ExoBDD Config

### 5.1 ExoBDD Seed Data

- [ ] ⏸ **GREEN**: Update `apps/jarga/priv/repo/exo_seeds.exs`
  - Add webhook-specific seed data after existing seeds:
    - Add `admin-key-product-team` API key for alice (admin/owner role) -- needed for BDD features that use `${valid-admin-key-product-team}`
    - Create seeded webhook subscriptions in product-team workspace:
      - `seeded-webhook-id` -- a basic active subscription
      - `seeded-active-webhook-id` -- another active subscription (for deactivation test)
      - `seeded-deactivated-webhook-id` -- an already-deactivated subscription
      - `seeded-deleted-webhook-id` -- a subscription that gets deleted during seeding (for 404 test)
    - Create seeded webhook deliveries for `seeded-webhook-with-deliveries-id`:
      - `seeded-success-delivery-id` -- status: success, response_code: 200
      - `seeded-failed-delivery-id` -- status: failed, response_code: 500
      - `seeded-retried-delivery-id` -- status: pending, with retry info
      - `seeded-pending-retry-delivery-id` -- status: pending, response_code: 500, next_retry_at set
      - `seeded-retried-success-delivery-id` -- status: success after retry (attempts > 1)
      - `seeded-exhausted-delivery-id` -- status: failed, attempts = max, no next_retry_at
    - `seeded-webhook-no-deliveries-id` -- subscription with no deliveries
    - Create inbound webhook config for product-team workspace with known secret
    - Add TRUNCATE statements for new tables
  - Use deterministic UUIDs for all seeded webhook records
  - Add deterministic admin API key token for alice

### 5.2 ExoBDD Config for webhooks_api

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/test/exo-bdd-webhooks-api.config.ts`
  - Follow `apps/jarga_api/test/exo-bdd-jarga-api.config.ts` pattern
  - Server config: port for webhooks_api (assign new dev/test ports, e.g., 4016/4017)
  - Seed command: same shared seed script
  - Variables mapping:
    - `valid-admin-key-product-team` -> deterministic admin token
    - `valid-member-key-product-team` -> deterministic member token (bob)
    - `revoked-key-product-team` -> deterministic revoked token
    - `seeded-webhook-id` -> deterministic UUID
    - `seeded-active-webhook-id` -> deterministic UUID
    - `seeded-deactivated-webhook-id` -> deterministic UUID
    - `seeded-deleted-webhook-id` -> deterministic UUID
    - `seeded-webhook-with-deliveries-id` -> deterministic UUID
    - `seeded-webhook-no-deliveries-id` -> deterministic UUID
    - `seeded-success-delivery-id` -> deterministic UUID
    - `seeded-failed-delivery-id` -> deterministic UUID
    - `seeded-retried-delivery-id` -> deterministic UUID
    - `seeded-pending-retry-delivery-id` -> deterministic UUID
    - `seeded-retried-success-delivery-id` -> deterministic UUID
    - `seeded-exhausted-delivery-id` -> deterministic UUID
    - `inbound-webhook-secret-product-team` -> the known inbound HMAC secret
    - `valid-inbound-signature` -> pre-computed HMAC-SHA256 for the standard test payload
    - `valid-inbound-signature-routable` -> pre-computed for the routable payload
    - `valid-inbound-signature-malformed` -> pre-computed for the malformed body
    - `valid-inbound-signature-audit` -> pre-computed for the audit test payload

### Phase 5 Validation

- [ ] ⏸ Seed script runs without errors: `MIX_ENV=test mix run --no-start apps/jarga/priv/repo/exo_seeds.exs`
- [ ] ⏸ All seeded UUIDs are deterministic and match config variables
- [ ] ⏸ Pre-computed HMAC signatures verify correctly against known secrets
- [ ] ⏸ ExoBDD config file is valid TypeScript

---

## Phase 6: Integration Wiring (mix.exs, supervision, config, boundary)

### 6.1 Webhooks App mix.exs

- [ ] ⏸ **GREEN**: Create `apps/webhooks/mix.exs`
  - Follow `apps/jarga/mix.exs` pattern (minus web/asset deps)
  - `app: :webhooks`
  - `compilers: [:boundary] ++ Mix.compilers()`
  - Deps: `identity` (in_umbrella), `jarga` (in_umbrella), `req`, `jason`, `boundary`
  - `elixirc_paths(:test)` includes `["lib", "test/support"]`
  - Boundary config: `externals_mode: :relaxed`, relaxed checks for phoenix, ecto, identity, jarga

### 6.2 WebhooksApi App mix.exs

- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/mix.exs`
  - Follow `apps/jarga_api/mix.exs` pattern
  - `app: :webhooks_api`
  - Deps: `phoenix`, `webhooks` (in_umbrella), `identity` (in_umbrella), `jarga` (in_umbrella), `jason`, `bandit`, `boundary`

### 6.3 Config Files

- [ ] ⏸ **GREEN**: Update `config/config.exs`
  - Add `config :webhooks_api, WebhooksApi.Endpoint, ...` (url, port, secret_key_base)
  - Add `config :webhooks_api, generators: [context_app: :webhooks]`
- [ ] ⏸ **GREEN**: Update `config/dev.exs`
  - Add `config :webhooks_api, WebhooksApi.Endpoint, http: [port: 4016], ...`
- [ ] ⏸ **GREEN**: Update `config/test.exs`
  - Add `config :webhooks_api, WebhooksApi.Endpoint, http: [port: 4017], server: true`
- [ ] ⏸ **GREEN**: Update `config/runtime.exs` (if needed)
  - Add production endpoint config for webhooks_api

### 6.4 Webhooks OTP Application

- [ ] ⏸ **GREEN**: Create `apps/webhooks/lib/webhooks_app.ex`
  ```elixir
  defmodule Webhooks.App do
    use Application
    use Boundary, deps: [Webhooks], exports: []

    @impl true
    def start(_type, _args) do
      children = [] ++ pubsub_subscribers()
      opts = [strategy: :one_for_one, name: Webhooks.Supervisor]
      Supervisor.start_link(children, opts)
    end

    defp pubsub_subscribers do
      env = Application.get_env(:webhooks, :env)
      enable_in_test = Application.get_env(:webhooks, :enable_pubsub_in_test, false)

      if env != :test or enable_in_test do
        [
          Webhooks.Infrastructure.Subscribers.OutboundWebhookHandler,
          Webhooks.Infrastructure.Workers.RetryWorker
        ]
      else
        []
      end
    end
  end
  ```

### 6.5 Test Support Files

- [ ] ⏸ **GREEN**: Create `apps/webhooks/test/test_helper.exs`
  - Standard ExUnit configuration
- [ ] ⏸ **GREEN**: Create `apps/webhooks/test/support/data_case.ex` (or reuse `Jarga.DataCase`)
  - Webhooks tests will use `Jarga.DataCase` since they share the same database
- [ ] ⏸ **GREEN**: Create `apps/webhooks_api/test/test_helper.exs`
  - Standard ExUnit configuration

### 6.6 Umbrella Apps Documentation Update

- [ ] ⏸ **GREEN**: Update `docs/umbrella_apps.md`
  - Add `webhooks` and `webhooks_api` to the app table with ports 4016/4017
  - Update dependency graph to show: `webhooks` depends on `identity`, `jarga`; `webhooks_api` depends on `webhooks`, `identity`, `jarga`

### Phase 6 Validation

- [ ] ⏸ `mix deps.get` succeeds
- [ ] ⏸ `mix compile` succeeds with no boundary warnings
- [ ] ⏸ `mix ecto.migrate` runs all new migrations
- [ ] ⏸ `mix boundary` reports no violations
- [ ] ⏸ Supervision tree starts OutboundWebhookHandler and RetryWorker in non-test env
- [ ] ⏸ Full test suite passes: `mix test`

---

## Pre-Commit Checkpoint

- [ ] ⏸ `mix precommit` passes (compile, format, credo, boundary, tests)
- [ ] ⏸ `mix boundary` reports no violations across entire umbrella

---

## Testing Strategy

### Estimated Test Distribution

| Layer | Count | Test Case | Async |
|-------|-------|-----------|-------|
| Domain entities (4) | ~12 | `ExUnit.Case, async: true` | Yes |
| Domain policies (4) | ~20 | `ExUnit.Case, async: true` | Yes |
| Application use cases (11) | ~55 | `Jarga.DataCase, async: false` | No |
| Infrastructure schemas (4) | ~20 | `Jarga.DataCase` | Yes |
| Infrastructure queries (3) | ~12 | `Jarga.DataCase` | Yes |
| Infrastructure repos (4) | ~16 | `Jarga.DataCase` | Yes |
| Infrastructure services (1) | ~6 | `ExUnit.Case` + Bypass | Yes |
| Infrastructure subscribers (1) | ~5 | `Jarga.DataCase` | No |
| Infrastructure workers (1) | ~3 | `Jarga.DataCase` | No |
| API controllers (4) | ~25 | `WebhooksApi.ConnCase` | Yes |
| API plugs (1) | ~4 | `WebhooksApi.ConnCase` | Yes |
| **Total** | **~178** | | |

### ExoBDD Acceptance Tests (external)

| Feature File | Scenarios | Type |
|-------------|-----------|------|
| `outbound.http.feature` | 28 | HTTP API |
| `inbound.http.feature` | 6 | HTTP API |
| `webhooks.security.feature` | 40 | Security (ZAP) |
| **Total** | **74** | |

---

## File Manifest

### New Files: `apps/webhooks/`

```
apps/webhooks/
├── mix.exs
├── lib/
│   ├── webhooks.ex                                          # Context facade
│   ├── webhooks/
│   │   ├── domain.ex                                        # Domain boundary
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── subscription.ex
│   │   │   │   ├── delivery.ex
│   │   │   │   ├── inbound_log.ex
│   │   │   │   └── inbound_webhook_config.ex
│   │   │   └── policies/
│   │   │       ├── webhook_authorization_policy.ex
│   │   │       ├── hmac_policy.ex
│   │   │       ├── retry_policy.ex
│   │   │       └── secret_generator_policy.ex
│   │   ├── application.ex                                   # Application boundary
│   │   ├── application/
│   │   │   ├── use_cases/
│   │   │   │   ├── use_case.ex                              # Behaviour
│   │   │   │   ├── create_subscription.ex
│   │   │   │   ├── list_subscriptions.ex
│   │   │   │   ├── get_subscription.ex
│   │   │   │   ├── update_subscription.ex
│   │   │   │   ├── delete_subscription.ex
│   │   │   │   ├── list_deliveries.ex
│   │   │   │   ├── get_delivery.ex
│   │   │   │   ├── dispatch_webhook.ex
│   │   │   │   ├── receive_inbound_webhook.ex
│   │   │   │   ├── list_inbound_logs.ex
│   │   │   │   └── retry_delivery.ex
│   │   │   └── behaviours/
│   │   │       ├── subscription_repository_behaviour.ex
│   │   │       ├── delivery_repository_behaviour.ex
│   │   │       ├── inbound_log_repository_behaviour.ex
│   │   │       ├── inbound_webhook_config_repository_behaviour.ex
│   │   │       └── http_dispatcher_behaviour.ex
│   │   ├── infrastructure.ex                                # Infrastructure boundary
│   │   └── infrastructure/
│   │       ├── schemas/
│   │       │   ├── subscription_schema.ex
│   │       │   ├── delivery_schema.ex
│   │       │   ├── inbound_webhook_config_schema.ex
│   │       │   └── inbound_log_schema.ex
│   │       ├── queries/
│   │       │   ├── subscription_queries.ex
│   │       │   ├── delivery_queries.ex
│   │       │   └── inbound_log_queries.ex
│   │       ├── repositories/
│   │       │   ├── subscription_repository.ex
│   │       │   ├── delivery_repository.ex
│   │       │   ├── inbound_log_repository.ex
│   │       │   └── inbound_webhook_config_repository.ex
│   │       ├── services/
│   │       │   └── http_dispatcher.ex
│   │       ├── subscribers/
│   │       │   └── outbound_webhook_handler.ex
│   │       └── workers/
│   │           └── retry_worker.ex
│   └── webhooks_app.ex                                      # OTP Application
├── test/
│   ├── test_helper.exs
│   └── webhooks/
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── subscription_test.exs
│       │   │   ├── delivery_test.exs
│       │   │   ├── inbound_log_test.exs
│       │   │   └── inbound_webhook_config_test.exs
│       │   └── policies/
│       │       ├── webhook_authorization_policy_test.exs
│       │       ├── hmac_policy_test.exs
│       │       ├── retry_policy_test.exs
│       │       └── secret_generator_policy_test.exs
│       ├── application/
│       │   └── use_cases/
│       │       ├── create_subscription_test.exs
│       │       ├── list_subscriptions_test.exs
│       │       ├── get_subscription_test.exs
│       │       ├── update_subscription_test.exs
│       │       ├── delete_subscription_test.exs
│       │       ├── list_deliveries_test.exs
│       │       ├── get_delivery_test.exs
│       │       ├── dispatch_webhook_test.exs
│       │       ├── receive_inbound_webhook_test.exs
│       │       ├── list_inbound_logs_test.exs
│       │       └── retry_delivery_test.exs
│       └── infrastructure/
│           ├── schemas/
│           │   ├── subscription_schema_test.exs
│           │   ├── delivery_schema_test.exs
│           │   ├── inbound_webhook_config_schema_test.exs
│           │   └── inbound_log_schema_test.exs
│           ├── queries/
│           │   ├── subscription_queries_test.exs
│           │   ├── delivery_queries_test.exs
│           │   └── inbound_log_queries_test.exs
│           ├── repositories/
│           │   ├── subscription_repository_test.exs
│           │   ├── delivery_repository_test.exs
│           │   ├── inbound_log_repository_test.exs
│           │   └── inbound_webhook_config_repository_test.exs
│           ├── services/
│           │   └── http_dispatcher_test.exs
│           ├── subscribers/
│           │   └── outbound_webhook_handler_test.exs
│           └── workers/
│               └── retry_worker_test.exs
```

### New Files: `apps/webhooks_api/`

```
apps/webhooks_api/
├── mix.exs
├── lib/
│   ├── webhooks_api.ex                                      # App module + boundary
│   └── webhooks_api/
│       ├── application.ex                                   # OTP Application
│       ├── endpoint.ex                                      # Phoenix Endpoint
│       ├── router.ex                                        # Router
│       ├── error_json.ex                                    # Error rendering
│       ├── plugs/
│       │   ├── api_auth_plug.ex
│       │   ├── security_headers_plug.ex
│       │   └── cache_raw_body.ex
│       └── controllers/
│           ├── subscription_controller.ex
│           ├── subscription_api_json.ex
│           ├── delivery_controller.ex
│           ├── delivery_api_json.ex
│           ├── inbound_webhook_controller.ex
│           ├── inbound_webhook_api_json.ex
│           ├── inbound_log_controller.ex
│           └── inbound_log_api_json.ex
├── test/
│   ├── test_helper.exs
│   ├── exo-bdd-webhooks-api.config.ts
│   ├── features/
│   │   └── webhooks/
│   │       ├── outbound.http.feature                        # (already exists)
│   │       ├── inbound.http.feature                         # (already exists)
│   │       └── webhooks.security.feature                    # (already exists)
│   ├── support/
│   │   └── conn_case.ex
│   └── webhooks_api/
│       ├── plugs/
│       │   └── cache_raw_body_test.exs
│       └── controllers/
│           ├── subscription_controller_test.exs
│           ├── delivery_controller_test.exs
│           ├── inbound_webhook_controller_test.exs
│           └── inbound_log_controller_test.exs
```

### Modified Files

```
apps/jarga/priv/repo/migrations/
├── YYYYMMDDHHMMSS_create_webhook_subscriptions.exs         # New migration
├── YYYYMMDDHHMMSS_create_webhook_deliveries.exs            # New migration
├── YYYYMMDDHHMMSS_create_inbound_webhook_configs.exs       # New migration
└── YYYYMMDDHHMMSS_create_inbound_webhook_logs.exs          # New migration

apps/jarga/priv/repo/exo_seeds.exs                          # Modified: add webhook seeds

config/config.exs                                            # Modified: add webhooks_api config
config/dev.exs                                               # Modified: add webhooks_api endpoint
config/test.exs                                              # Modified: add webhooks_api endpoint

docs/umbrella_apps.md                                        # Modified: add webhooks + webhooks_api
```
