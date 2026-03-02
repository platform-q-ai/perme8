# Perme8 Dashboard

Unified dev-tool dashboard for the Perme8 platform. Provides a tabbed navigation layout that mounts views from other dev tools as content tabs.

## Purpose

Serves as the central hub for developer tooling. Currently mounts the Exo Dashboard's BDD feature browser under a "Features" tab, with the architecture designed to accommodate additional tabs (e.g., Sessions).

## Dependencies

- `exo_dashboard` (in_umbrella) -- provides `DashboardLive` and `FeatureDetailLive` views
- `jarga` -- shared PubSub (`Jarga.PubSub`)

## Configuration

| Environment | Port |
|-------------|------|
| Dev         | 4012 |
| Test        | 4012 |

Dev-only application -- not included in production releases.

## Usage

Start the dashboard in dev:

```bash
mix phx.server
# or from the umbrella root:
iex -S mix phx.server
```

Then visit `http://localhost:4012`.

## Architecture

The dashboard is a pure interface app with no domain logic. It provides:

- **Root layout** -- HTML skeleton with DaisyUI dark theme
- **App layout** -- Header with branding + tab bar navigation + content area
- **Tab navigation** -- Data-driven `tab_bar` component accepting `{key, label, path}` tuples
- **Router** -- Mounts exo_dashboard LiveViews in its own `live_session` with perme8_dashboard layouts

Exo dashboard views render their content (feature tree, feature detail) inside the perme8_dashboard layout. The exo_dashboard app retains its own endpoint for standalone use without the dashboard shell.

## Testing

```bash
# Unit and integration tests
mix test apps/perme8_dashboard/test/

# BDD browser tests (requires running server)
mix exo_test apps/perme8_dashboard/test/exo-bdd-perme8-dashboard.config.ts
```
