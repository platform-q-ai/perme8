# WebhooksApi

Dedicated JSON REST API application for webhook management and inbound webhook reception. Provides endpoints for outbound subscription CRUD, delivery log inspection, and inbound webhook handling with HMAC signature verification.

## Architecture

WebhooksApi follows Clean Architecture with its own endpoint, router, and controllers:

```
Interface (Controllers, JSON Views, Plugs, Router, Endpoint)
    |
Webhooks (Context Facade -- delegates to domain/application/infrastructure)
```

### Controllers

| Controller | Endpoints |
|------------|-----------|
| `SubscriptionApiController` | Create, list, get, update, delete webhook subscriptions |
| `DeliveryApiController` | List and get delivery attempts for a subscription |
| `InboundWebhookApiController` | Receive inbound webhooks (HMAC auth, no Bearer token) |
| `InboundLogApiController` | List inbound webhook audit logs |

### Plugs

| Plug | Description |
|------|-------------|
| `ApiAuthPlug` | Bearer token authentication via Identity API key verification |
| `SecurityHeadersPlug` | Security headers (CSP, HSTS, X-Frame-Options, etc.) |
| `CacheRawBody` | Preserves raw request body for HMAC signature verification |

### JSON Views

`SubscriptionApiJSON`, `DeliveryApiJSON`, `InboundWebhookApiJSON`, `InboundLogApiJSON`

## API Routes

### Authenticated routes (Bearer token required)

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/workspaces/:slug/webhooks` | Create a webhook subscription (returns secret) |
| `GET` | `/api/workspaces/:slug/webhooks` | List subscriptions (no secrets) |
| `GET` | `/api/workspaces/:slug/webhooks/:id` | Get subscription (no secret) |
| `PATCH` | `/api/workspaces/:slug/webhooks/:id` | Update subscription |
| `DELETE` | `/api/workspaces/:slug/webhooks/:id` | Delete subscription |
| `GET` | `/api/workspaces/:slug/webhooks/:sub_id/deliveries` | List deliveries |
| `GET` | `/api/workspaces/:slug/webhooks/:sub_id/deliveries/:id` | Get delivery details |
| `GET` | `/api/workspaces/:slug/webhooks/inbound/logs` | List inbound audit logs |

### Inbound webhook route (HMAC signature auth)

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/workspaces/:slug/webhooks/inbound` | Receive inbound webhook |

The inbound endpoint authenticates via `X-Webhook-Signature` header (HMAC-SHA256), not Bearer token.

## Dependencies

- **`webhooks`** (in_umbrella) -- core domain logic, context facade
- **`identity`** (in_umbrella) -- API key verification and user resolution
- **`jarga`** (in_umbrella) -- workspace resolution, shared DataCase
- Phoenix, Jason, Bandit -- web framework and HTTP server
- Boundary -- compile-time boundary enforcement

## Ports

| Environment | Port |
|-------------|------|
| Dev | 4016 |
| Test | 4017 |

## Testing

```bash
# Run webhooks_api tests
mix test apps/webhooks_api/test
```

### ExoBDD Acceptance Tests

```bash
# HTTP API tests (36 scenarios, 297 steps)
npx exo-bdd --config apps/webhooks_api/test/exo-bdd-webhooks-api.config.ts --adapter http

# Security tests (ZAP vulnerability scanning)
npx exo-bdd --config apps/webhooks_api/test/exo-bdd-webhooks-api.config.ts --adapter security
```

Feature files: `outbound.http.feature` (28 scenarios), `inbound.http.feature` (8 scenarios), `webhooks.security.feature`.
