# JargaWeb

Phoenix LiveView browser interface for the Perme8 platform. Serves the full-stack web application on port 4000, providing interactive pages for workspace management, project management, document editing, agent configuration, chat, notifications, and user settings.

## Architecture

JargaWeb is the interface layer for the browser, consuming domain logic from the `jarga` app and authentication from `identity`:

```
JargaWeb (LiveViews, Components, Controllers, Plugs)
    |
Jarga (core domain) + Identity (authentication)
```

## LiveViews

| LiveView | Description |
|----------|-------------|
| `DashboardLive` | Main dashboard after login |
| `WorkspaceLive.Index` | List and manage workspaces |
| `WorkspaceLive.New` | Create a new workspace |
| `WorkspaceLive.Show` | Workspace detail with projects and members |
| `WorkspaceLive.Edit` | Edit workspace settings |
| `ProjectLive.Show` | Project detail with documents |
| `ProjectLive.Edit` | Edit project settings |
| `DocumentLive.Show` | Document viewer/editor |
| `AgentLive.Index` | List agents for a workspace |
| `AgentLive.Form` | Create/edit agent configuration |
| `ChatLive.Panel` | Real-time chat panel with message handlers |
| `NotificationLive.Bell` | Notification bell component |
| `UserLoginLive` | User login page |
| `UserRegistrationLive` | User registration page |
| `UserSettingsLive` | User account settings |
| `UserConfirmationLive` | Email confirmation page |
| `ApiKeysLive` | API key management |

## Components

| Module | Description |
|--------|-------------|
| `CoreComponents` | Shared UI components (buttons, forms, modals, tables, flash messages) |
| `Layouts` | Application layout templates (root, app) |

## Controllers

| Controller | Description |
|------------|-------------|
| `PageController` | Landing page |
| `UserSessionController` | Session create/delete (login/logout) |

## Supporting Modules

| Module | Description |
|--------|-------------|
| `DocumentSaveDebouncer` | GenServer that debounces document saves to avoid excessive writes |
| `PermissionsHelper` | Helper functions for checking user permissions in templates |
| `AllowEctoSandbox` | Test hook for Ecto sandbox in Wallaby browser tests |
| `NotificationLive.OnMount` | Mount hook for loading notifications on page load |

## Assets

- **Tailwind CSS 4** -- utility-first CSS framework
- **esbuild** -- TypeScript/JavaScript bundling
- **Heroicons** -- SVG icon library
- TypeScript entry point at `assets/js/app.ts`

```bash
# Build assets for development
mix assets.build

# Build assets for production (minified, digested)
mix assets.deploy

# Copy font files
mix assets.copy_fonts
```

## Dependencies

- **`jarga`** (in_umbrella) -- core domain logic
- Phoenix, Phoenix LiveView, Phoenix LiveDashboard -- web framework
- esbuild, tailwind -- asset compilation
- Heroicons -- icon components
- Wallaby, Cucumber -- browser-based BDD testing
- Boundary -- compile-time boundary enforcement

## Running

```bash
# Start the web server
mix phx.server

# Or within IEx
iex -S mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) in your browser.

## Testing

```bash
# Run jarga_web tests
mix test apps/jarga_web/test

# Run browser-based BDD feature tests
mix test apps/jarga_web/test --include feature
```
