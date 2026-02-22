# Feature: Webhooks Module for Inbound and Outbound Webhook Support

**Ticket:** #176
**Status:** ✓ Complete
**Last Updated:** 2026-02-22

## Overview

Add a `Webhooks` bounded context within the `jarga` app to support:

1. **Outbound webhooks** — workspace admins register HTTP endpoints; domain events matching subscribed event types trigger signed HTTP POST deliveries with retry logic.
2. **Inbound webhooks** — authenticated receiver endpoints accept external payloads, verify HMAC signatures, route to pluggable handlers, and audit-log every request.

This is a new context (`Jarga.Webhooks`) following the existing three-layer architecture (Domain → Application → Infrastructure) with API routes in `jarga_api`.

## UI Strategy

- **LiveView coverage**: 0% — this is a pure API feature. No LiveView needed.
- **TypeScript needed**: None — all interactions are via REST API.

## Affected Boundaries

- **New context**: `Jarga.Webhooks` (with `Domain`, `Application`, `Infrastructure` sub-boundaries)
- **Primary app**: `jarga` (domain/application/infrastructure layers)
- **API app**: `jarga_api` (controller/JSON view/routes/plugs)
- **Cross-context dependencies**:
  - `Identity` — user lookup, API key verification (via existing `ApiAuthPlug`)
  - `Jarga.Workspaces` — workspace membership/role verification
  - `Perme8.Events` — `EventBus`, `EventHandler`, `DomainEvent`, `TestEventBus`
  - `Jarga.Domain` — `DomainPermissionsPolicy` for admin-only authorization
- **Exported from Webhooks**:
  - `Domain.Entities.WebhookSubscription`
  - `Domain.Entities.WebhookDelivery`
  - `Domain.Entities.InboundWebhook`

## BDD Feature File Mapping

| BDD Feature File | Scenarios | Covered By Phases |
|---|---|---|
| `outbound.http.feature` | 30 scenarios | Phases 1–4 |
| `inbound.http.feature` | 6 scenarios | Phases 1–4 |
| `webhooks.security.feature` | 34 scenarios | Phase 4 (inherits SecurityHeadersPlug) |

---

## Test Setup (Phase 0) ✓

Before implementation, set up the testing infrastructure.

### 0.1 Mox Mock Definitions

- [x] ✓ Add mock definitions to `apps/jarga/test/support/mocks.ex`:
  - `Jarga.Webhooks.Mocks.MockWebhookRepository`
  - `Jarga.Webhooks.Mocks.MockDeliveryRepository`
  - `Jarga.Webhooks.Mocks.MockInboundWebhookRepository`
  - `Jarga.Webhooks.Mocks.MockHttpClient`

### 0.2 Test Helpers / Fixtures

- [x] ✓ Create `apps/jarga/test/support/fixtures/webhook_fixtures.ex`
  - Factory functions: `webhook_subscription_fixture/1`, `webhook_delivery_fixture/1`, `inbound_webhook_fixture/1`
  - Uses infrastructure schemas + Repo for database-backed fixtures

---

## Phase 1: Domain Layer (phoenix-tdd) ✓

**Goal:** Pure business logic — entities, events, policies. Zero I/O, no Ecto, no Repo.

All tests use `ExUnit.Case, async: true` — millisecond execution.

### 1.1 Domain Entity: WebhookSubscription

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/domain/entities/webhook_subscription_test.exs`
  - Tests:
    - `new/1` creates struct from attrs map
    - `from_map/1` alias for `new/1`
    - Default values: `is_active: true`, `event_types: []`
    - All fields present: `id`, `url`, `secret`, `event_types`, `is_active`, `workspace_id`, `created_by_id`, `inserted_at`, `updated_at`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/domain/entities/webhook_subscription.ex`
  - Pure struct with `defstruct`, `@type t`, `new/1`, `from_map/1`
- [x] ✓ **REFACTOR**: Clean up typespecs and docs

### 1.2 Domain Entity: WebhookDelivery

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/domain/entities/webhook_delivery_test.exs`
  - Tests:
    - `new/1` creates struct from attrs
    - `from_map/1` alias for `new/1`
    - Fields: `id`, `webhook_subscription_id`, `event_type`, `payload`, `status`, `response_code`, `response_body`, `attempts`, `max_attempts`, `next_retry_at`, `inserted_at`, `updated_at`
    - Status values: `"pending"`, `"success"`, `"failed"`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/domain/entities/webhook_delivery.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.3 Domain Entity: InboundWebhook

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/domain/entities/inbound_webhook_test.exs`
  - Tests:
    - `new/1` creates struct from attrs
    - `from_map/1` alias for `new/1`
    - Fields: `id`, `workspace_id`, `event_type`, `payload`, `source_ip`, `signature_valid`, `handler_result`, `received_at`, `inserted_at`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/domain/entities/inbound_webhook.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.4 Domain Events

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/domain/events/webhook_events_test.exs`
  - Tests:
    - `WebhookSubscriptionCreated.new/1` generates event_id, occurred_at, correct event_type
    - `WebhookSubscriptionUpdated.new/1` same
    - `WebhookSubscriptionDeleted.new/1` same
    - `WebhookDeliveryCompleted.new/1` same (includes delivery_id, status)
    - `InboundWebhookReceived.new/1` same (includes signature_valid)
    - All events derive correct `event_type` (e.g., `"webhooks.webhook_subscription_created"`)
- [x] ✓ **GREEN**: Implement domain events:
  - `apps/jarga/lib/webhooks/domain/events/webhook_subscription_created.ex`
  - `apps/jarga/lib/webhooks/domain/events/webhook_subscription_updated.ex`
  - `apps/jarga/lib/webhooks/domain/events/webhook_subscription_deleted.ex`
  - `apps/jarga/lib/webhooks/domain/events/webhook_delivery_completed.ex`
  - `apps/jarga/lib/webhooks/domain/events/inbound_webhook_received.ex`
  - Each uses `use Perme8.Events.DomainEvent` with appropriate `aggregate_type` and `fields`
- [x] ✓ **REFACTOR**: Clean up

### 1.5 Domain Policy: WebhookPolicy

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/domain/policies/webhook_policy_test.exs`
  - Tests:
    - `can_manage_webhooks?/1` — only `:admin` and `:owner` roles return true
    - `:member` and `:guest` return false
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/domain/policies/webhook_policy.ex`
  - Pure functions, no I/O
- [x] ✓ **REFACTOR**: Clean up

### 1.6 Domain Policy: DeliveryPolicy

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/domain/policies/delivery_policy_test.exs`
  - Tests:
    - `should_retry?/2` — returns true when `attempts < max_attempts` and status is `"pending"` or `"failed"`
    - `should_retry?/2` — returns false when `attempts >= max_attempts`
    - `should_retry?/2` — returns false when status is `"success"`
    - `next_retry_delay/1` — exponential backoff: attempt 1 → 60s, 2 → 120s, 3 → 240s, etc.
    - `next_retry_at/2` — returns DateTime offset from base_time by `next_retry_delay(attempt)`
    - `max_retries_exhausted?/2` — true when `attempts >= max_attempts`
    - Default max_attempts is 5 (configurable)
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/domain/policies/delivery_policy.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.7 Domain Policy: SignaturePolicy

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/domain/policies/signature_policy_test.exs`
  - Tests:
    - `sign/2` — generates HMAC-SHA256 hex digest of payload using secret
    - `verify/3` — returns true when computed HMAC matches provided signature
    - `verify/3` — returns false for mismatched signature
    - `verify/3` — returns false for nil/empty signature
    - `build_signature_header/2` — returns `"sha256=<hex>"` format string
    - `parse_signature_header/1` — extracts hex digest from `"sha256=<hex>"` format
    - `parse_signature_header/1` — returns `{:error, :invalid_format}` for bad input
    - Timing-safe comparison (uses `Plug.Crypto.secure_compare`)
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/domain/policies/signature_policy.ex`
  - Note: `:crypto` is an Erlang stdlib, not I/O — acceptable in domain layer
- [x] ✓ **REFACTOR**: Clean up

### 1.8 Domain Policy: EventFilterPolicy

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/domain/policies/event_filter_policy_test.exs`
  - Tests:
    - `matches?/2` — event_type "projects.project_created" matches subscription with `["projects.project_created"]`
    - `matches?/2` — returns false when event_type not in subscription's event_types
    - `matches?/2` — empty event_types list matches ALL events (wildcard)
    - `matches?/2` — nil event_types matches ALL events
    - `valid_event_types?/1` — validates list of event type strings (format: `"context.event_name"`)
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/domain/policies/event_filter_policy.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.9 Domain Boundary Declaration

- [x] ✓ Create `apps/jarga/lib/webhooks/domain.ex`

### 1.10 Application Behaviours

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/behaviours/behaviours_test.exs`
  - Tests: Verify each behaviour module defines the expected callbacks (compile-time check)
- [x] ✓ **GREEN**: Implement behaviours:
  - `apps/jarga/lib/webhooks/application/behaviours/webhook_repository_behaviour.ex`
    - `@callback insert(map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}`
    - `@callback update(struct(), map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}`
    - `@callback delete(struct(), keyword()) :: {:ok, struct()} | {:error, term()}`
    - `@callback get(String.t(), keyword()) :: struct() | nil`
    - `@callback list_for_workspace(String.t(), keyword()) :: [struct()]`
    - `@callback list_active_for_event(String.t(), String.t(), keyword()) :: [struct()]`
  - `apps/jarga/lib/webhooks/application/behaviours/delivery_repository_behaviour.ex`
    - `@callback insert(map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}`
    - `@callback update(struct(), map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}`
    - `@callback get(String.t(), keyword()) :: struct() | nil`
    - `@callback list_for_subscription(String.t(), keyword()) :: [struct()]`
    - `@callback list_pending_retries(keyword()) :: [struct()]`
  - `apps/jarga/lib/webhooks/application/behaviours/inbound_webhook_repository_behaviour.ex`
    - `@callback insert(map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}`
    - `@callback list_for_workspace(String.t(), keyword()) :: [struct()]`
  - `apps/jarga/lib/webhooks/application/behaviours/http_client_behaviour.ex`
    - `@callback post(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}`
- [x] ✓ **REFACTOR**: Clean up

### 1.11 Application Use Case: CreateWebhookSubscription

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/create_webhook_subscription_test.exs`
  - Uses `Jarga.DataCase, async: true` with Mox mocks
  - Tests:
    - Happy path: admin creates subscription → `{:ok, subscription}`, event emitted
    - Auto-generates signing secret (32+ chars)
    - Validates URL is present
    - Rejects non-admin role → `{:error, :forbidden}`
    - Rejects non-member → `{:error, :unauthorized}`
    - Changeset errors bubble up → `{:error, changeset}`
  - Mocks: `MockWebhookRepository`, `TestEventBus`, workspace membership via DI
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/create_webhook_subscription.ex`
  - DI pattern: `@default_webhook_repository`, `@default_event_bus`
  - `execute(%{actor:, workspace_id:, attrs:}, opts \\ [])`
  - Steps: get member → authorize (admin/owner) → generate secret → insert → emit event
- [x] ✓ **REFACTOR**: Clean up

### 1.12 Application Use Case: ListWebhookSubscriptions

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/list_webhook_subscriptions_test.exs`
  - Tests:
    - Admin lists subscriptions → `{:ok, [subscriptions]}`
    - Non-admin → `{:error, :forbidden}`
  - Mocks: `MockWebhookRepository`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/list_webhook_subscriptions.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.13 Application Use Case: GetWebhookSubscription

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/get_webhook_subscription_test.exs`
  - Tests:
    - Admin gets subscription → `{:ok, subscription}`
    - Not found → `{:error, :not_found}`
    - Non-admin → `{:error, :forbidden}`
  - Mocks: `MockWebhookRepository`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/get_webhook_subscription.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.14 Application Use Case: UpdateWebhookSubscription

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/update_webhook_subscription_test.exs`
  - Tests:
    - Admin updates URL → `{:ok, updated_subscription}`
    - Admin deactivates (is_active: false) → `{:ok, deactivated_subscription}`
    - Not found → `{:error, :not_found}`
    - Non-admin → `{:error, :forbidden}`
    - Event emitted on success
  - Mocks: `MockWebhookRepository`, `TestEventBus`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/update_webhook_subscription.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.15 Application Use Case: DeleteWebhookSubscription

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/delete_webhook_subscription_test.exs`
  - Tests:
    - Admin deletes subscription → `{:ok, deleted_subscription}`
    - Not found → `{:error, :not_found}`
    - Non-admin → `{:error, :forbidden}`
    - Event emitted on success
  - Mocks: `MockWebhookRepository`, `TestEventBus`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/delete_webhook_subscription.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.16 Application Use Case: DispatchWebhookDelivery

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/dispatch_webhook_delivery_test.exs`
  - Tests:
    - Dispatches HTTP POST to subscription URL with signed payload → creates delivery record with status "success"
    - Signs payload with HMAC-SHA256 using subscription secret
    - Sends `X-Webhook-Signature` header
    - On HTTP success (2xx): delivery status = "success", response_code set
    - On HTTP failure (4xx/5xx): delivery status = "pending", attempts incremented, next_retry_at calculated
    - On connection error: delivery status = "pending", attempts incremented
    - Max retries exhausted: status = "failed", no next_retry_at
    - Event emitted (`WebhookDeliveryCompleted`) on every attempt
    - Skips inactive subscriptions
  - Mocks: `MockHttpClient`, `MockDeliveryRepository`, `MockWebhookRepository`, `TestEventBus`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/dispatch_webhook_delivery.ex`
  - `execute(%{subscription:, event_type:, payload:}, opts \\ [])`
  - Steps: build payload → sign → HTTP POST → record delivery → emit event
- [x] ✓ **REFACTOR**: Clean up

### 1.17 Application Use Case: RetryWebhookDelivery

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/retry_webhook_delivery_test.exs`
  - Tests:
    - Retries a pending delivery → re-sends HTTP POST → updates delivery record
    - On success: status = "success", next_retry_at cleared
    - On failure with retries remaining: status = "pending", next_retry_at recalculated
    - On failure with retries exhausted: status = "failed", next_retry_at cleared
    - Does not retry deliveries already in "success" state
  - Mocks: `MockHttpClient`, `MockDeliveryRepository`, `MockWebhookRepository`, `TestEventBus`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/retry_webhook_delivery.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.18 Application Use Case: ListDeliveries

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/list_deliveries_test.exs`
  - Tests:
    - Admin lists deliveries for a subscription → `{:ok, [deliveries]}`
    - Non-admin → `{:error, :forbidden}`
  - Mocks: `MockDeliveryRepository`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/list_deliveries.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.19 Application Use Case: GetDelivery

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/get_delivery_test.exs`
  - Tests:
    - Admin gets delivery by ID → `{:ok, delivery}`
    - Not found → `{:error, :not_found}`
    - Non-admin → `{:error, :forbidden}`
  - Mocks: `MockDeliveryRepository`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/get_delivery.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.20 Application Use Case: ProcessInboundWebhook

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/process_inbound_webhook_test.exs`
  - Tests:
    - Valid signature + valid JSON → `{:ok, inbound_webhook}`, audit logged, handler called
    - Invalid signature → `{:error, :invalid_signature}`
    - Missing signature → `{:error, :missing_signature}`
    - Malformed JSON → `{:error, :invalid_payload}`
    - Event emitted (`InboundWebhookReceived`)
  - Mocks: `MockInboundWebhookRepository`, `TestEventBus`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/process_inbound_webhook.ex`
  - `execute(%{workspace_id:, raw_body:, signature:, source_ip:, workspace_secret:}, opts \\ [])`
- [x] ✓ **REFACTOR**: Clean up

### 1.21 Application Use Case: ListInboundWebhookLogs

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/application/use_cases/list_inbound_webhook_logs_test.exs`
  - Tests:
    - Admin lists logs → `{:ok, [inbound_webhooks]}`
    - Non-admin → `{:error, :forbidden}`
  - Mocks: `MockInboundWebhookRepository`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/application/use_cases/list_inbound_webhook_logs.ex`
- [x] ✓ **REFACTOR**: Clean up

### 1.22 Application Boundary Declaration

- [x] ✓ Create `apps/jarga/lib/webhooks/application.ex` with boundary declaration

### Phase 1 Validation

- [x] ✓ All domain tests pass with `async: true` (milliseconds, no I/O)
- [x] ✓ All application tests pass with Mox mocks
- [x] ✓ No boundary violations (`mix compile --force`)
- [x] ✓ `mix format` passes
- [x] ✓ `mix compile --warnings-as-errors` passes

**Estimated tests: ~65** (Domain: ~30, Application: ~35)

---

## Phase 2: Infrastructure Layer (phoenix-tdd) ✓

**Goal:** Database schemas, migrations, repositories, queries, HTTP client service, and EventHandler subscriber.

Tests use `Jarga.DataCase` for DB-backed tests.

### 2.1 Ecto Migrations

- [x] ✓ Create `apps/jarga/priv/repo/migrations/20260222120000_create_webhook_subscriptions.exs`
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

- [x] ✓ Create `apps/jarga/priv/repo/migrations/20260222120001_create_webhook_deliveries.exs`
  ```elixir
  create table(:webhook_deliveries, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :webhook_subscription_id, references(:webhook_subscriptions, type: :binary_id, on_delete: :delete_all), null: false
    add :event_type, :string, null: false
    add :payload, :map, null: false
    add :status, :string, null: false, default: "pending"
    add :response_code, :integer
    add :response_body, :text
    add :attempts, :integer, null: false, default: 0
    add :max_attempts, :integer, null: false, default: 5
    add :next_retry_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
  create index(:webhook_deliveries, [:webhook_subscription_id])
  create index(:webhook_deliveries, [:status, :next_retry_at])
  ```

- [x] ✓ Create `apps/jarga/priv/repo/migrations/20260222120002_create_inbound_webhooks.exs`
  ```elixir
  create table(:inbound_webhooks, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
    add :event_type, :string
    add :payload, :map
    add :source_ip, :string
    add :signature_valid, :boolean, null: false, default: false
    add :handler_result, :string
    add :received_at, :utc_datetime, null: false
    timestamps(type: :utc_datetime)
  end
  create index(:inbound_webhooks, [:workspace_id])
  create index(:inbound_webhooks, [:workspace_id, :received_at])
  ```

### 2.2 Infrastructure Schema: WebhookSubscriptionSchema

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/schemas/webhook_subscription_schema_test.exs`
  - Tests:
    - Valid changeset with all required fields
    - Invalid changeset when URL missing → error on `:url`
    - Invalid changeset when workspace_id missing
    - `event_types` defaults to `[]`
    - `is_active` defaults to `true`
    - URL validation (format)
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/schemas/webhook_subscription_schema.ex`
  - `use Ecto.Schema`, `import Ecto.Changeset`
  - `@primary_key {:id, :binary_id, autogenerate: true}`, `@foreign_key_type :binary_id`
  - Schema `"webhook_subscriptions"` with all fields
  - `changeset/2` with cast, validate_required, validate_format (URL)
- [x] ✓ **REFACTOR**: Clean up

### 2.3 Infrastructure Schema: WebhookDeliverySchema

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/schemas/webhook_delivery_schema_test.exs`
  - Tests:
    - Valid changeset
    - Required: `webhook_subscription_id`, `event_type`, `payload`
    - Default `status: "pending"`, `attempts: 0`, `max_attempts: 5`
    - Status must be one of: `"pending"`, `"success"`, `"failed"`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/schemas/webhook_delivery_schema.ex`
- [x] ✓ **REFACTOR**: Clean up

### 2.4 Infrastructure Schema: InboundWebhookSchema

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/schemas/inbound_webhook_schema_test.exs`
  - Tests:
    - Valid changeset
    - Required: `workspace_id`, `received_at`
    - `signature_valid` defaults to `false`
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/schemas/inbound_webhook_schema.ex`
- [x] ✓ **REFACTOR**: Clean up

### 2.5 Infrastructure Queries: WebhookQueries

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/queries/webhook_queries_test.exs`
  - Tests (with `DataCase`):
    - `base/0` returns queryable
    - `for_workspace/2` filters by workspace_id
    - `active/1` filters `is_active: true`
    - `active_for_event/3` filters by workspace_id + is_active + event_type in event_types array
    - `by_id/2` filters by id
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/queries/webhook_queries.ex`
  - All functions return `Ecto.Queryable`, not results
  - Uses `import Ecto.Query`
- [x] ✓ **REFACTOR**: Clean up

### 2.6 Infrastructure Queries: DeliveryQueries

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/queries/delivery_queries_test.exs`
  - Tests:
    - `for_subscription/2` filters by webhook_subscription_id
    - `by_id/2` filters by id
    - `pending_retries/1` filters status="pending" AND next_retry_at <= now
    - `ordered/1` orders by inserted_at desc
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/queries/delivery_queries.ex`
- [x] ✓ **REFACTOR**: Clean up

### 2.7 Infrastructure Queries: InboundWebhookQueries

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/queries/inbound_webhook_queries_test.exs`
  - Tests:
    - `for_workspace/2` filters by workspace_id
    - `ordered/1` orders by received_at desc
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/queries/inbound_webhook_queries.ex`
- [x] ✓ **REFACTOR**: Clean up

### 2.8 Infrastructure Repository: WebhookRepository

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/repositories/webhook_repository_test.exs`
  - Tests (with `DataCase`):
    - `insert/2` creates subscription, returns `{:ok, domain_entity}`
    - `update/3` updates subscription, returns `{:ok, domain_entity}`
    - `delete/2` deletes subscription, returns `{:ok, domain_entity}`
    - `get/2` returns domain entity or nil
    - `list_for_workspace/2` returns list of domain entities
    - `list_active_for_event/3` returns subscriptions matching workspace + event_type
    - All functions return domain entities via `to_domain/1` conversion
  - Requires running migration first
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/repositories/webhook_repository.ex`
  - `@behaviour Jarga.Webhooks.Application.Behaviours.WebhookRepositoryBehaviour`
  - Uses `WebhookQueries`, converts to domain entities via `to_domain/1`
- [x] ✓ **REFACTOR**: Clean up

### 2.9 Infrastructure Repository: DeliveryRepository

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/repositories/delivery_repository_test.exs`
  - Tests:
    - `insert/2` creates delivery record
    - `update/3` updates delivery (status, attempts, next_retry_at, response_code, response_body)
    - `get/2` returns delivery or nil
    - `list_for_subscription/2` returns deliveries for a subscription
    - `list_pending_retries/1` returns deliveries ready for retry
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/repositories/delivery_repository.ex`
  - `@behaviour Jarga.Webhooks.Application.Behaviours.DeliveryRepositoryBehaviour`
- [x] ✓ **REFACTOR**: Clean up

### 2.10 Infrastructure Repository: InboundWebhookRepository

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/repositories/inbound_webhook_repository_test.exs`
  - Tests:
    - `insert/2` creates inbound webhook record
    - `list_for_workspace/2` returns inbound webhooks for a workspace, ordered by received_at desc
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/repositories/inbound_webhook_repository.ex`
  - `@behaviour Jarga.Webhooks.Application.Behaviours.InboundWebhookRepositoryBehaviour`
- [x] ✓ **REFACTOR**: Clean up

### 2.11 Infrastructure Service: HttpClient

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/services/http_client_test.exs`
  - Tests (with Bypass):
    - `post/3` sends HTTP POST with JSON body and headers → returns `{:ok, %{status: 200, body: ...}}`
    - Sends `Content-Type: application/json`
    - Sends `X-Webhook-Signature` header when provided
    - On connection error → returns `{:error, reason}`
    - On timeout → returns `{:error, :timeout}`
    - Configurable timeout via opts
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/services/http_client.ex`
  - `@behaviour Jarga.Webhooks.Application.Behaviours.HttpClientBehaviour`
  - Uses `Req.post/2` (already a dependency)
  - Wraps response in normalized `{:ok, %{status:, body:}}` or `{:error, reason}`
- [x] ✓ **REFACTOR**: Clean up

### 2.12 Infrastructure Subscriber: WebhookDispatchSubscriber

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/infrastructure/subscribers/webhook_dispatch_subscriber_test.exs`
  - Tests (with `DataCase, async: false`):
    - Subscribes to all context event topics
    - On receiving a domain event:
      - Queries active subscriptions matching event_type + workspace_id
      - Calls `DispatchWebhookDelivery.execute/2` for each matching subscription
    - Ignores events with no matching subscriptions
    - Handles errors gracefully (logs, doesn't crash)
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks/infrastructure/subscribers/webhook_dispatch_subscriber.ex`
  - `use Perme8.Events.EventHandler`
  - Subscribes to broad event topics (e.g., all context topics or `events:workspace:*` pattern)
  - `handle_event/1` queries subscriptions and dispatches
- [x] ✓ **REFACTOR**: Clean up

### 2.13 Infrastructure Boundary Declaration

- [x] ✓ Create `apps/jarga/lib/webhooks/infrastructure.ex`:
  ```elixir
  defmodule Jarga.Webhooks.Infrastructure do
    use Boundary,
      top_level?: true,
      deps: [
        Jarga.Webhooks.Domain,
        Jarga.Webhooks.Application,
        Jarga.Repo,
        Identity
      ],
      exports: [
        Schemas.WebhookSubscriptionSchema,
        Schemas.WebhookDeliverySchema,
        Schemas.InboundWebhookSchema,
        Repositories.WebhookRepository,
        Repositories.DeliveryRepository,
        Repositories.InboundWebhookRepository,
        Services.HttpClient,
        Queries.WebhookQueries,
        Queries.DeliveryQueries,
        Queries.InboundWebhookQueries,
        Subscribers.WebhookDispatchSubscriber
      ]
  end
  ```

### 2.14 Context Facade: Jarga.Webhooks

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks_test.exs`
  - Tests (integration with `DataCase`):
    - `create_subscription/3` delegates to use case
    - `list_subscriptions/2` delegates to use case
    - `get_subscription/3` delegates to use case
    - `update_subscription/4` delegates to use case
    - `delete_subscription/3` delegates to use case
    - `list_deliveries/3` delegates to use case
    - `get_delivery/3` delegates to use case
    - `process_inbound_webhook/2` delegates to use case
    - `list_inbound_logs/2` delegates to use case
- [x] ✓ **GREEN**: Implement `apps/jarga/lib/webhooks.ex`
  ```elixir
  defmodule Jarga.Webhooks do
    use Boundary,
      top_level?: true,
      deps: [
        Identity,
        Jarga.Workspaces,
        Jarga.Webhooks.Domain,
        Jarga.Webhooks.Application,
        Jarga.Webhooks.Infrastructure,
        Jarga.Repo
      ],
      exports: [
        {Domain.Entities.WebhookSubscription, []},
        {Domain.Entities.WebhookDelivery, []},
        {Domain.Entities.InboundWebhook, []}
      ]

    # Public API: thin delegation to use cases
    # ... (see implementation for full list)
  end
  ```
- [x] ✓ **REFACTOR**: Clean up

### 2.15 Register Subscriber in Application Supervisor

- [x] ✓ Update `apps/jarga/lib/application.ex`
  - Add `Jarga.Webhooks.Infrastructure.Subscribers.WebhookDispatchSubscriber` to `pubsub_subscribers/0`
  - Same pattern as existing `WorkspaceInvitationSubscriber`

### 2.16 Update Boundary Dependencies

- [x] ✓ Update `apps/jarga/lib/application.ex` — removed invalid `Jarga.Webhooks.Infrastructure` dep (not a valid sibling for boundary); subscriber reference is runtime-only via child spec list
- [x] ✓ WebhookPolicy already handles webhook permissions in Domain layer (Phase 1)

### Phase 2 Validation

- [x] ✓ Migrations run successfully (`mix ecto.migrate`)
- [x] ✓ All infrastructure tests pass
- [x] ✓ All repository tests pass with real database
- [x] ✓ HttpClient tests pass with Bypass
- [x] ✓ Subscriber tests pass
- [x] ✓ Context facade tests pass
- [x] ✓ No boundary violations (`mix compile --force --warnings-as-errors` — zero warnings)
- [x] ✓ `mix format` passes
- [x] ✓ `mix credo` passes (advisory warnings only — domain events tested in combined test file)

**Estimated tests: ~45** (Schemas: ~8, Queries: ~10, Repositories: ~12, Services: ~5, Subscriber: ~5, Facade: ~5)

---

## Phase 3: Interface Layer — API Controllers (phoenix-tdd) ✓

**Goal:** REST API endpoints in `jarga_api` for webhook management, delivery logs, and inbound webhook reception.

Tests use `JargaApi.ConnCase`.

### 3.1 Workspace Webhook Auth Plug (optional, for inbound)

- [x] ✓ **RED**: Write test `apps/jarga_api/test/jarga_api/plugs/webhook_auth_plug_test.exs`
  - Tests:
    - Valid `X-Webhook-Signature` header → conn passes through with `signature` assign
    - Missing signature header → 401 response
    - Extracts raw body for signature verification
- [x] ✓ **GREEN**: Implement `apps/jarga_api/lib/jarga_api/plugs/webhook_auth_plug.ex`
  - Reads `X-Webhook-Signature` header
  - Assigns `:webhook_signature` to conn
  - Does NOT halt — signature verification happens in the use case
  - For missing signature: halts with 401
- [x] ✓ **REFACTOR**: Clean up

### 3.2 Raw Body Reader Plug

- [x] ✓ **RED**: Write test `apps/jarga_api/test/jarga_api/plugs/raw_body_reader_test.exs`
  - Tests:
    - Stores raw request body in conn private for HMAC verification
    - Works with JSON content-type
- [x] ✓ **GREEN**: Implement `apps/jarga_api/lib/jarga_api/plugs/raw_body_reader.ex`
  - Custom body reader that caches raw body in `conn.private[:raw_body]`
  - Used by the inbound webhook endpoint for signature verification
- [x] ✓ **REFACTOR**: Clean up

### 3.3 Outbound Webhook Controller

- [x] ✓ **RED**: Write test `apps/jarga_api/test/jarga_api/controllers/webhook_api_controller_test.exs`
  - Tests:
    - **Create**: POST `/api/workspaces/:slug/webhooks` with valid attrs → 201 + `$.data`
    - **Create**: missing URL → 422 + `$.errors.url`
    - **Create**: non-admin → 403
    - **Create**: unauthenticated → 401
    - **List**: GET `/api/workspaces/:slug/webhooks` → 200 + `$.data[]`
    - **List**: non-admin → 403
    - **Show**: GET `/api/workspaces/:slug/webhooks/:id` → 200 + `$.data`
    - **Show**: not found → 404
    - **Update**: PATCH `/api/workspaces/:slug/webhooks/:id` with URL → 200 + updated `$.data`
    - **Update**: PATCH with event_types → 200
    - **Update**: PATCH with is_active: false → 200, `$.data.is_active` = false
    - **Update**: not found → 404
    - **Delete**: DELETE `/api/workspaces/:slug/webhooks/:id` → 200
    - **Delete**: verify deleted → 404 on subsequent GET
  - Setup: create workspace, user, API key, workspace membership fixtures
  - Maps to BDD: `outbound.http.feature` scenarios 1–14
- [x] ✓ **GREEN**: Implement `apps/jarga_api/lib/jarga_api/controllers/webhook_api_controller.ex`
  - Actions: `create`, `index`, `show`, `update`, `delete`
  - Each action: extract user/api_key from conn → resolve workspace → delegate to `Jarga.Webhooks`
  - Pattern matches on error tuples → appropriate HTTP status codes
- [x] ✓ **REFACTOR**: Keep controller thin — delegate to context

### 3.4 Delivery Logs Controller

- [x] ✓ **RED**: Write test `apps/jarga_api/test/jarga_api/controllers/delivery_api_controller_test.exs`
  - Tests:
    - **List**: GET `/api/workspaces/:slug/webhooks/:id/deliveries` → 200 + `$.data[]`
    - **Show**: GET `/api/workspaces/:slug/webhooks/:id/deliveries/:delivery_id` → 200 + `$.data`
    - **Show**: includes `status`, `response_code`, `attempts`, `next_retry_at`, `event_type`, `payload`
    - **List**: non-admin → 403
    - **Show**: not found → 404
  - Maps to BDD: `outbound.http.feature` delivery log scenarios (22–30)
- [x] ✓ **GREEN**: Implement `apps/jarga_api/lib/jarga_api/controllers/delivery_api_controller.ex`
  - Actions: `index`, `show`
  - Delegates to `Jarga.Webhooks.list_deliveries/3` and `Jarga.Webhooks.get_delivery/3`
- [x] ✓ **REFACTOR**: Clean up

### 3.5 Inbound Webhook Controller

- [x] ✓ **RED**: Write test `apps/jarga_api/test/jarga_api/controllers/inbound_webhook_api_controller_test.exs`
  - Tests:
    - **Receive**: POST `/api/workspaces/:slug/webhooks/inbound` with valid signature → 200
    - **Receive**: invalid signature → 401
    - **Receive**: missing signature → 401
    - **Receive**: malformed JSON → 400
    - **Audit logs**: GET `/api/workspaces/:slug/webhooks/inbound/logs` → 200 + `$.data[]`
    - **Audit logs**: includes `event_type`, `payload`, `signature_valid`, `received_at`
    - **Audit logs**: non-admin → 403
  - Maps to BDD: `inbound.http.feature` all 6 scenarios
- [x] ✓ **GREEN**: Implement `apps/jarga_api/lib/jarga_api/controllers/inbound_webhook_api_controller.ex`
  - Actions: `receive`, `logs`
  - `receive/2`: extracts raw body + signature → delegates to `Jarga.Webhooks.process_inbound_webhook/2`
  - `logs/2`: delegates to `Jarga.Webhooks.list_inbound_logs/2`
- [x] ✓ **REFACTOR**: Clean up

### 3.6 JSON Views

- [x] ✓ Implement `apps/jarga_api/lib/jarga_api/controllers/webhook_api_json.ex`
  - `index/1` → `%{data: [subscription_data]}`
  - `show/1` → `%{data: subscription_data}` (includes `id`, `url`, `event_types`, `is_active`, `secret`)
  - `validation_error/1` → `%{errors: ...}`
  - `error/1` → `%{error: message}`
  - `deleted/1` → `%{data: %{id: ..., deleted: true}}`

- [x] ✓ Implement `apps/jarga_api/lib/jarga_api/controllers/delivery_api_json.ex`
  - `index/1` → `%{data: [delivery_data]}`
  - `show/1` → `%{data: delivery_data}` (includes `id`, `event_type`, `status`, `response_code`, `attempts`, `next_retry_at`, `payload`, `created_at`)
  - `error/1` → `%{error: message}`

- [x] ✓ Implement `apps/jarga_api/lib/jarga_api/controllers/inbound_webhook_api_json.ex`
  - `received/1` → `%{data: %{status: "accepted"}}`
  - `logs/1` → `%{data: [inbound_webhook_data]}` (includes `event_type`, `payload`, `signature_valid`, `received_at`)
  - `error/1` → `%{error: message}`

### 3.7 Router Configuration

- [x] ✓ Update `apps/jarga_api/lib/jarga_api/router.ex`
  - Add webhook routes inside existing authenticated scope:
    ```elixir
    scope "/api", JargaApi do
      pipe_through([:api_base, :api_authenticated])

      # ... existing routes ...

      # Outbound webhook subscriptions
      resources "/workspaces/:workspace_slug/webhooks", WebhookApiController,
        only: [:create, :index, :show, :update, :delete]

      # Delivery logs
      get "/workspaces/:workspace_slug/webhooks/:webhook_id/deliveries",
        DeliveryApiController, :index
      get "/workspaces/:workspace_slug/webhooks/:webhook_id/deliveries/:id",
        DeliveryApiController, :show

      # Inbound webhook audit logs (admin-authenticated)
      get "/workspaces/:workspace_slug/webhooks/inbound/logs",
        InboundWebhookApiController, :logs
    end

    # Inbound webhook receiver (signature-authenticated, NOT bearer token)
    scope "/api", JargaApi do
      pipe_through([:api_base])

      post "/workspaces/:workspace_slug/webhooks/inbound",
        InboundWebhookApiController, :receive
    end
    ```
  - Note: Inbound receiver does NOT go through `api_authenticated` pipeline (uses signature auth instead)

### 3.8 Update JargaApi Boundary

- [x] ✓ Update `apps/jarga_api/lib/jarga_api.ex` boundary deps to include `Jarga.Webhooks`, `Identity.Repo`, `JargaApi.Accounts.Domain`

### Phase 3 Validation

- [x] ✓ All controller tests pass (29 tests, 0 failures)
- [x] ✓ All JSON view tests pass (implicitly tested via controller tests)
- [x] ✓ Routes resolve correctly (`mix phx.routes JargaApi.Router`)
- [x] ✓ No boundary violations (`mix compile --force --warnings-as-errors` — zero warnings)
- [x] ✓ `mix format` passes
- [x] ✓ `mix credo` passes (advisory only — existing domain event warnings unrelated to Phase 3)

**Estimated tests: ~30** (Controllers: ~22, Plugs: ~5, Integration: ~3)

---

## Phase 4: Integration & End-to-End Validation ✓

**Goal:** Full integration tests, BDD scenario readiness, and pre-commit validation.

### 4.1 Integration Test: Outbound Webhook Flow

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/integration/outbound_flow_test.exs`
  - Tests (with `DataCase, async: false` + Bypass):
    - Create subscription → trigger domain event → verify HTTP POST received by Bypass → verify delivery record created
    - Signed payload is verifiable with subscription secret
    - Inactive subscription does not trigger delivery
    - Non-matching event type does not trigger delivery
    - Failed delivery creates record with retry info
- [x] ✓ **GREEN**: All tests pass — full stack works end-to-end
- [x] ✓ **REFACTOR**: Clean up

### 4.2 Integration Test: Inbound Webhook Flow

- [x] ✓ **RED**: Write test `apps/jarga_api/test/jarga_api/integration/inbound_webhook_flow_test.exs`
  - Tests (with `ConnCase`):
    - POST to inbound endpoint with valid signature → 200, audit log created
    - POST with invalid signature → 401, audit log NOT created
    - Admin can view audit logs via GET
- [x] ✓ **GREEN**: All tests pass
- [x] ✓ **REFACTOR**: Clean up

### 4.3 Integration Test: Retry Flow

- [x] ✓ **RED**: Write test `apps/jarga/test/webhooks/integration/retry_flow_test.exs`
  - Tests (with `DataCase, async: false` + Bypass):
    - Failed delivery → retry succeeds → status updated to "success"
    - Failed delivery → retry fails → attempts incremented, next_retry_at set
    - Max retries exhausted → status "failed", no next_retry_at
- [x] ✓ **GREEN**: All tests pass
- [x] ✓ **REFACTOR**: Clean up

### Phase 4 Validation

- [x] ✓ All integration tests pass (8 tests across 3 files, 0 failures)
- [x] ✓ Full test suite passes (`mix test` — 3,596 tests, 0 failures)
- [x] ✓ No boundary violations (`mix compile --force --warnings-as-errors` — zero warnings)
- [x] ✓ `mix format` passes
- [x] ✓ `mix credo` passes (advisory only)

**Estimated tests: ~12** (Integration: ~12)

---

## Pre-commit Checkpoint

- [x] ✓ `mix precommit` passes from umbrella root
- [x] ✓ `mix boundary` passes with zero violations (compile with --warnings-as-errors)
- [x] ✓ All tests pass: `mix test` from umbrella root (3,407+ tests, 0 failures)
- [x] ✓ Migrations are reversible (`mix ecto.rollback --step 3` + `mix ecto.migrate`)

---

## Testing Strategy Summary

| Layer | Test Count | Test Type | Async? |
|---|---|---|---|
| Domain Entities | ~8 | `ExUnit.Case` | Yes |
| Domain Policies | ~20 | `ExUnit.Case` | Yes |
| Domain Events | ~6 | `ExUnit.Case` | Yes |
| Application Use Cases | ~35 | `DataCase` + Mox | Yes |
| Application Behaviours | ~2 | `ExUnit.Case` | Yes |
| Infrastructure Schemas | ~8 | `DataCase` | Yes |
| Infrastructure Queries | ~10 | `DataCase` | Yes |
| Infrastructure Repos | ~12 | `DataCase` | Yes |
| Infrastructure Services | ~5 | `DataCase` + Bypass | Yes |
| Infrastructure Subscriber | ~5 | `DataCase` | No |
| Context Facade | ~5 | `DataCase` | Yes |
| API Controllers | ~22 | `ConnCase` | Yes |
| API Plugs | ~5 | `ConnCase` | Yes |
| Integration | ~12 | `DataCase`/`ConnCase` + Bypass | No |
| **Total** | **~155** | | |

**Distribution:** Domain: ~36 (23%), Application: ~37 (24%), Infrastructure: ~45 (29%), Interface: ~27 (17%), Integration: ~12 (8%)

---

## File Manifest

### New Files in `apps/jarga/`

```
lib/webhooks.ex                                                    # Context facade
lib/webhooks/domain.ex                                             # Domain boundary
lib/webhooks/application.ex                                        # Application boundary
lib/webhooks/infrastructure.ex                                     # Infrastructure boundary
lib/webhooks/domain/entities/webhook_subscription.ex               # Entity
lib/webhooks/domain/entities/webhook_delivery.ex                   # Entity
lib/webhooks/domain/entities/inbound_webhook.ex                    # Entity
lib/webhooks/domain/events/webhook_subscription_created.ex         # Event
lib/webhooks/domain/events/webhook_subscription_updated.ex         # Event
lib/webhooks/domain/events/webhook_subscription_deleted.ex         # Event
lib/webhooks/domain/events/webhook_delivery_completed.ex           # Event
lib/webhooks/domain/events/inbound_webhook_received.ex             # Event
lib/webhooks/domain/policies/webhook_policy.ex                     # Policy
lib/webhooks/domain/policies/delivery_policy.ex                    # Policy
lib/webhooks/domain/policies/signature_policy.ex                   # Policy
lib/webhooks/domain/policies/event_filter_policy.ex                # Policy
lib/webhooks/application/behaviours/webhook_repository_behaviour.ex
lib/webhooks/application/behaviours/delivery_repository_behaviour.ex
lib/webhooks/application/behaviours/inbound_webhook_repository_behaviour.ex
lib/webhooks/application/behaviours/http_client_behaviour.ex
lib/webhooks/application/use_cases/create_webhook_subscription.ex
lib/webhooks/application/use_cases/list_webhook_subscriptions.ex
lib/webhooks/application/use_cases/get_webhook_subscription.ex
lib/webhooks/application/use_cases/update_webhook_subscription.ex
lib/webhooks/application/use_cases/delete_webhook_subscription.ex
lib/webhooks/application/use_cases/dispatch_webhook_delivery.ex
lib/webhooks/application/use_cases/retry_webhook_delivery.ex
lib/webhooks/application/use_cases/list_deliveries.ex
lib/webhooks/application/use_cases/get_delivery.ex
lib/webhooks/application/use_cases/process_inbound_webhook.ex
lib/webhooks/application/use_cases/list_inbound_webhook_logs.ex
lib/webhooks/infrastructure/schemas/webhook_subscription_schema.ex
lib/webhooks/infrastructure/schemas/webhook_delivery_schema.ex
lib/webhooks/infrastructure/schemas/inbound_webhook_schema.ex
lib/webhooks/infrastructure/queries/webhook_queries.ex
lib/webhooks/infrastructure/queries/delivery_queries.ex
lib/webhooks/infrastructure/queries/inbound_webhook_queries.ex
lib/webhooks/infrastructure/repositories/webhook_repository.ex
lib/webhooks/infrastructure/repositories/delivery_repository.ex
lib/webhooks/infrastructure/repositories/inbound_webhook_repository.ex
lib/webhooks/infrastructure/services/http_client.ex
lib/webhooks/infrastructure/subscribers/webhook_dispatch_subscriber.ex
priv/repo/migrations/20260222120000_create_webhook_subscriptions.exs
priv/repo/migrations/20260222120001_create_webhook_deliveries.exs
priv/repo/migrations/20260222120002_create_inbound_webhooks.exs
```

### New Files in `apps/jarga_api/`

```
lib/jarga_api/controllers/webhook_api_controller.ex
lib/jarga_api/controllers/webhook_api_json.ex
lib/jarga_api/controllers/delivery_api_controller.ex
lib/jarga_api/controllers/delivery_api_json.ex
lib/jarga_api/controllers/inbound_webhook_api_controller.ex
lib/jarga_api/controllers/inbound_webhook_api_json.ex
lib/jarga_api/plugs/webhook_auth_plug.ex
lib/jarga_api/plugs/raw_body_reader.ex
```

### New Test Files in `apps/jarga/`

```
test/support/fixtures/webhook_fixtures.ex
test/webhooks/domain/entities/webhook_subscription_test.exs
test/webhooks/domain/entities/webhook_delivery_test.exs
test/webhooks/domain/entities/inbound_webhook_test.exs
test/webhooks/domain/events/webhook_events_test.exs
test/webhooks/domain/policies/webhook_policy_test.exs
test/webhooks/domain/policies/delivery_policy_test.exs
test/webhooks/domain/policies/signature_policy_test.exs
test/webhooks/domain/policies/event_filter_policy_test.exs
test/webhooks/application/behaviours/behaviours_test.exs
test/webhooks/application/use_cases/create_webhook_subscription_test.exs
test/webhooks/application/use_cases/list_webhook_subscriptions_test.exs
test/webhooks/application/use_cases/get_webhook_subscription_test.exs
test/webhooks/application/use_cases/update_webhook_subscription_test.exs
test/webhooks/application/use_cases/delete_webhook_subscription_test.exs
test/webhooks/application/use_cases/dispatch_webhook_delivery_test.exs
test/webhooks/application/use_cases/retry_webhook_delivery_test.exs
test/webhooks/application/use_cases/list_deliveries_test.exs
test/webhooks/application/use_cases/get_delivery_test.exs
test/webhooks/application/use_cases/process_inbound_webhook_test.exs
test/webhooks/application/use_cases/list_inbound_webhook_logs_test.exs
test/webhooks/infrastructure/schemas/webhook_subscription_schema_test.exs
test/webhooks/infrastructure/schemas/webhook_delivery_schema_test.exs
test/webhooks/infrastructure/schemas/inbound_webhook_schema_test.exs
test/webhooks/infrastructure/queries/webhook_queries_test.exs
test/webhooks/infrastructure/queries/delivery_queries_test.exs
test/webhooks/infrastructure/queries/inbound_webhook_queries_test.exs
test/webhooks/infrastructure/repositories/webhook_repository_test.exs
test/webhooks/infrastructure/repositories/delivery_repository_test.exs
test/webhooks/infrastructure/repositories/inbound_webhook_repository_test.exs
test/webhooks/infrastructure/services/http_client_test.exs
test/webhooks/infrastructure/subscribers/webhook_dispatch_subscriber_test.exs
test/webhooks_test.exs
test/webhooks/integration/outbound_flow_test.exs
test/webhooks/integration/retry_flow_test.exs
```

### New Test Files in `apps/jarga_api/`

```
test/jarga_api/plugs/webhook_auth_plug_test.exs
test/jarga_api/plugs/raw_body_reader_test.exs
test/jarga_api/controllers/webhook_api_controller_test.exs
test/jarga_api/controllers/delivery_api_controller_test.exs
test/jarga_api/controllers/inbound_webhook_api_controller_test.exs
test/jarga_api/integration/inbound_webhook_flow_test.exs
```

### Modified Files

```
apps/jarga/lib/application.ex                    # Add WebhookDispatchSubscriber
apps/jarga/test/support/mocks.ex                  # Add Mox mock definitions
apps/jarga_api/lib/jarga_api.ex                   # Update Boundary deps
apps/jarga_api/lib/jarga_api/router.ex            # Add webhook routes
```

---

## BDD Scenario Coverage Traceability

### outbound.http.feature (30 scenarios)

| Scenario | Covered By |
|---|---|
| Workspace admin registers webhook | Phase 3.3 (create action) + Phase 1.11 (CreateWebhookSubscription) |
| Signing secret auto-generated | Phase 1.11 (secret generation in use case) |
| Invalid data returns 422 | Phase 3.3 (validation error handling) |
| Admin lists subscriptions | Phase 3.3 (index action) + Phase 1.12 |
| Admin retrieves subscription | Phase 3.3 (show action) + Phase 1.13 |
| Non-existent returns 404 | Phase 3.3 (not_found error) |
| Admin updates URL | Phase 3.3 (update action) + Phase 1.14 |
| Admin updates event_types | Phase 3.3 (update action) + Phase 1.14 |
| Update non-existent 404 | Phase 3.3 (not_found error) |
| Admin deactivates | Phase 3.3 (update is_active) + Phase 1.14 |
| Deactivated subscription state | Phase 3.3 (show action) |
| Admin deletes | Phase 3.3 (delete action) + Phase 1.15 |
| Deleted not retrievable | Phase 3.3 (show 404) |
| Non-admin create 403 | Phase 1.5 (WebhookPolicy) + Phase 1.11 + Phase 3.3 |
| Non-admin list 403 | Phase 1.5 + Phase 1.12 + Phase 3.3 |
| Non-admin update 403 | Phase 1.5 + Phase 1.14 + Phase 3.3 |
| Non-admin delete 403 | Phase 1.5 + Phase 1.15 + Phase 3.3 |
| Unauthenticated 401 | Existing ApiAuthPlug |
| Invalid API key 401 | Existing ApiAuthPlug |
| Revoked API key 401 | Existing ApiAuthPlug |
| Delivery history | Phase 3.4 (index action) + Phase 1.18 |
| Retry information | Phase 3.4 (show action) + Phase 1.19 |
| Failure reason | Phase 3.4 (show action) |
| Non-admin delivery logs 403 | Phase 1.5 + Phase 3.4 |
| Successful dispatch record | Phase 1.16 (DispatchWebhookDelivery) + Phase 3.4 |
| Signature metadata | Phase 1.7 (SignaturePolicy) + Phase 1.16 |
| Non-matching event filter | Phase 1.8 (EventFilterPolicy) + Phase 2.12 |
| Pending retry record | Phase 1.6 (DeliveryPolicy) + Phase 1.16 |
| Successful retry record | Phase 1.17 (RetryWebhookDelivery) |
| Exhausted retries record | Phase 1.6 + Phase 1.17 |

### inbound.http.feature (6 scenarios)

| Scenario | Covered By |
|---|---|
| Valid payload accepted | Phase 3.5 (receive action) + Phase 1.20 |
| Routed to handler | Phase 1.20 (ProcessInboundWebhook) |
| Invalid signature 401 | Phase 1.7 (SignaturePolicy) + Phase 3.5 |
| Missing signature 401 | Phase 3.1 (WebhookAuthPlug) + Phase 3.5 |
| Audit log recorded | Phase 1.20 + Phase 1.21 + Phase 3.5 |
| Malformed JSON 400 | Phase 3.5 (receive action error handling) |

### webhooks.security.feature (34 scenarios)

| Scenario Group | Covered By |
|---|---|
| Spider discovery (4) | Phase 3.7 (routes exist) |
| Passive scanning (5) | Existing SecurityHeadersPlug + proper JSON responses |
| SQL injection (4) | Ecto parameterized queries throughout |
| XSS (4) | JSON-only responses, no HTML rendering |
| Path traversal (3) | Phoenix router path matching |
| Command injection (2) | No system calls in codebase |
| SSRF (1) | URL validation in schema + policy |
| Cross-workspace (1) | Workspace membership check in use cases |
| Baseline scans (4) | All above combined |
| Comprehensive scan (1) | All above combined |
| Security headers (3) | Existing SecurityHeadersPlug |
| Audit report (1) | All above combined |
