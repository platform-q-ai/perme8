# Perme8 Plugs

Shared Plug infrastructure for the Perme8 umbrella. Provides reusable Plug modules used across multiple interface apps.

## Modules

### `Perme8.Plugs.SecurityHeaders`

Adds standard security headers to all HTTP responses with profile-specific Content-Security-Policy:

- **`:liveview`** -- permissive CSP with `'unsafe-inline'` for script-src/style-src (required by Phoenix LiveView)
- **`:api`** -- restrictive `default-src 'none'` CSP for JSON-only APIs

```elixir
# In a LiveView endpoint:
plug Perme8.Plugs.SecurityHeaders, profile: :liveview

# In an API router pipeline:
plug Perme8.Plugs.SecurityHeaders, profile: :api
```

Headers set by both profiles:

| Header | Value |
|--------|-------|
| `x-content-type-options` | `nosniff` |
| `x-frame-options` | `DENY` |
| `referrer-policy` | `strict-origin-when-cross-origin` |
| `strict-transport-security` | `max-age=31536000; includeSubDomains` |
| `permissions-policy` | `camera=(), microphone=(), geolocation=()` |
| `content-security-policy` | Profile-dependent (see above) |

## Dependencies

None (leaf-node shared infrastructure, depends only on `plug`).

## Testing

```bash
mix test apps/perme8_plugs/test
```
