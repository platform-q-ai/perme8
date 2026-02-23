# Webhooks

Core domain logic for outbound webhook dispatch and inbound webhook reception. Supports event-driven HTTP POST delivery with HMAC-SHA256 signing, exponential backoff retries, and inbound signature verification with audit logging.

## Architecture

Webhooks follows Clean Architecture with compile-time boundary enforcement:

```
Application (Use Cases, Behaviours)
    |
Domain (Entities, Policies)
    |
Infrastructure (Ecto Schemas, Repositories, Queries, Services, Subscribers, Workers)
```

### Domain Layer

| Module | Description |
|--------|-------------|
| `Subscription` | Outbound webhook subscription entity (url, secret, event_types, is_active) |
| `Delivery` | Delivery attempt entity with status tracking and retry metadata |
| `InboundLog` | Inbound webhook reception audit log entity |
| `InboundWebhookConfig` | Per-workspace inbound webhook configuration (secret, is_active) |
| `WebhookAuthorizationPolicy` | Role-based access -- only `:owner` and `:admin` can manage webhooks |
| `HmacPolicy` | HMAC-SHA256 signature computation and verification (strips `sha256=` prefix) |
| `RetryPolicy` | Exponential backoff: `15 * 2^attempt` seconds (15s, 30s, 60s, 120s, 240s), max 5 retries |
| `SecretGeneratorPolicy` | Cryptographic secret generation (32+ character URL-safe tokens) |

### Application Layer

11 use cases covering outbound subscription CRUD, delivery logs, webhook dispatch, inbound reception, and retry logic:

| Use Case | Description |
|----------|-------------|
| `CreateSubscription` | Create subscription with auto-generated HMAC secret |
| `ListSubscriptions` | List subscriptions for workspace (secrets stripped) |
| `GetSubscription` | Get subscription by ID (secret stripped) |
| `UpdateSubscription` | Update url, event_types, is_active |
| `DeleteSubscription` | Delete subscription |
| `ListDeliveries` | List delivery attempts for a subscription |
| `GetDelivery` | Get delivery details (payload, attempts, retry info) |
| `DispatchWebhook` | Find matching subscriptions, compute HMAC, dispatch HTTP POST, record result |
| `ReceiveInboundWebhook` | Verify HMAC signature, record inbound log |
| `ListInboundLogs` | List inbound webhook audit logs for workspace |
| `RetryDelivery` | Re-dispatch a pending delivery, update attempts and status |

All use cases follow the `@behaviour UseCase` pattern with dependency injection via `Keyword.get(opts, :key, @default)`.

### Infrastructure Layer

| Module | Description |
|--------|-------------|
| `SubscriptionSchema` | Ecto schema for `webhook_subscriptions` table |
| `DeliverySchema` | Ecto schema for `webhook_deliveries` table |
| `InboundWebhookConfigSchema` | Ecto schema for `inbound_webhook_configs` table |
| `InboundLogSchema` | Ecto schema for `inbound_webhook_logs` table |
| `SubscriptionQueries` | Composable Ecto queries for subscriptions |
| `DeliveryQueries` | Composable Ecto queries for deliveries |
| `InboundLogQueries` | Composable Ecto queries for inbound logs |
| `SubscriptionRepository` | CRUD operations, converts to/from domain entities |
| `DeliveryRepository` | Delivery persistence and status updates |
| `InboundLogRepository` | Inbound log persistence |
| `InboundWebhookConfigRepository` | Config lookup by workspace |
| `HttpDispatcher` | HTTP POST dispatch via `Req` with HMAC signature header |
| `OutboundWebhookHandler` | PubSub GenServer subscribing to `events:projects` and `events:documents` |
| `RetryWorker` | GenServer polling for pending retries every 30 seconds |

### Context Facade

`Webhooks` (`apps/webhooks/lib/webhooks.ex`) -- 9 public functions wiring workspace resolution, authorization, and use case delegation.

## Database

`Webhooks.Repo` (`apps/webhooks/lib/webhooks/repo.ex`) points to the shared PostgreSQL database. Migrations are at `apps/webhooks/priv/repo/migrations/`.

Tables: `webhook_subscriptions`, `webhook_deliveries`, `inbound_webhook_configs`, `inbound_webhook_logs`.

## Dependencies

- **`identity`** (in_umbrella) -- API key verification, user lookup
- **`jarga`** (in_umbrella) -- workspace resolution, PubSub event infrastructure
- Req -- HTTP client for outbound dispatch
- Boundary -- compile-time boundary enforcement

## Testing

```bash
# Run all webhooks tests
mix test apps/webhooks/test

# Run domain tests only (fast, no DB)
mix test apps/webhooks/test/webhooks/domain/

# Run a specific layer
mix test apps/webhooks/test/webhooks/application/
mix test apps/webhooks/test/webhooks/infrastructure/
```

228 unit tests across domain (32), application (46), and infrastructure (150). Uses `Jarga.DataCase` for DB tests, `Bypass` for HTTP dispatcher tests, and in-memory test doubles for use case isolation.
