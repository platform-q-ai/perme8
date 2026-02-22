# Feature: Create Perme8 Dashboard and Migrate Exo Dashboard Layout

## Overview

Create a new `perme8_dashboard` Phoenix umbrella app that serves as the unified dev-tool dashboard. It provides a tabbed navigation layout and mounts the existing `exo_dashboard` views (DashboardLive, FeatureDetailLive) under its "Features" tab. The exo_dashboard app is refactored to remove its own layout chrome (drawer/sidebar/topbar), becoming a pure view provider. The Perme8 Dashboard runs on port 4012 (dev) / 4013 (test) and is dev-only (excluded from production releases).

## Architectural Decision: Direct Module Reference

`perme8_dashboard` depends on `exo_dashboard` at the Elixir level. The perme8_dashboard router directly references `ExoDashboardWeb.DashboardLive` and `ExoDashboardWeb.FeatureDetailLive` within its own `live_session`. Layout chrome comes from `perme8_dashboard`; exo_dashboard views render content only.

**Key implications:**
- `perme8_dashboard` lists `{:exo_dashboard, in_umbrella: true}` in deps
- `perme8_dashboard`'s router mounts exo LiveViews in its own `live_session`
- Exo LiveViews use `ExoDashboardWeb, :live_view` which includes `ExoDashboardWeb.CoreComponents` — these components must continue to work when rendered inside the perme8_dashboard layout
- Exo's `app.html.heex` becomes a minimal pass-through (just `{@inner_content}`)
- Exo's `root.html.heex` stays as-is for standalone use; perme8_dashboard overrides root layout via its pipeline

## UI Strategy

- **LiveView coverage**: 100% — all UI is server-rendered with LiveView
- **TypeScript needed**: Minimal — only the existing `ScrollToHash` hook from exo_dashboard (reused), plus standard topbar/LiveSocket wiring for the new app

## Affected Boundaries

- **New app**: `perme8_dashboard` / `perme8_dashboard_web` (single app, like exo_dashboard's structure)
- **Modified app**: `exo_dashboard` (layout removal)
- **Primary context**: `Perme8DashboardWeb` (interface-only, no domain logic)
- **Dependencies**: `ExoDashboardWeb` (LiveViews, components), `ExoDashboard.Features` (indirectly, through exo LiveViews)
- **Exported schemas**: None (no database)
- **New context needed?**: No — this is purely an interface/shell app

## BDD Acceptance Specifications

The implementation must satisfy all scenarios in:
1. `apps/perme8_dashboard/test/features/dashboard/dashboard.browser.feature` (11 scenarios)
2. `apps/perme8_dashboard/test/features/dashboard/dashboard.security.feature` (4 scenarios)
3. `apps/exo_dashboard/test/features/dashboard.browser.feature` — specifically the "Exo Dashboard serves layout-less views after migration" scenario

---

## Phase 1: Scaffold perme8_dashboard App (phoenix-tdd) ✓

This phase creates the new umbrella app skeleton. Since `perme8_dashboard` is a pure interface app (no domain entities, no policies, no use cases), Phase 1 focuses on the application scaffold, configuration, and the Perme8DashboardWeb module.

### Step 1.1: Generate Phoenix App Skeleton

Generate the app in `apps/` using `mix phx.new` with no Ecto, no mailer:

```bash
cd apps && mix phx.new perme8_dashboard --no-ecto --no-mailer --no-dashboard
```

Then customise the generated files:

**Files to create/modify:**
- `apps/perme8_dashboard/mix.exs`
- `apps/perme8_dashboard/lib/perme8_dashboard.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard/application.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/endpoint.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/router.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/telemetry.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/gettext.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/controllers/error_html.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/components/layouts.ex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/components/layouts/root.html.heex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/components/layouts/app.html.heex`
- `apps/perme8_dashboard/lib/perme8_dashboard_web/components/core_components.ex`
- `apps/perme8_dashboard/test/test_helper.exs`
- `apps/perme8_dashboard/test/support/conn_case.ex`

- [x] ✓ **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/endpoint_test.exs`
  - Tests: Endpoint starts successfully, responds to health check
- [x] ✓ **GREEN**: Configure `mix.exs` with deps (including `{:exo_dashboard, in_umbrella: true}`), boundary config, application module
- [x] ✓ **REFACTOR**: Clean up generated boilerplate, remove unused files

### Step 1.2: Configure Umbrella Integration

**Files to modify:**
- `config/config.exs` — add Perme8Dashboard endpoint config, esbuild/tailwind profiles
- `config/dev.exs` — add dev endpoint config (port 4012), watchers, live_reload
- `config/test.exs` — add test endpoint config (port 4013)

- [x] ✓ **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/config_test.exs`
  - Tests: Endpoint config is set, port matches expected value, PubSub uses Jarga.PubSub
- [x] ✓ **GREEN**: Add all config entries for `perme8_dashboard`
- [x] ✓ **REFACTOR**: Ensure config follows same pattern as exo_dashboard entries

### Step 1.3: Boundary Configuration

**Files to create/modify:**
- `apps/perme8_dashboard/lib/perme8_dashboard.ex` — root boundary
- `apps/perme8_dashboard/lib/perme8_dashboard_web.ex` — web boundary with deps on ExoDashboardWeb

- [x] ✓ **RED**: Verify `mix boundary` passes with no violations (compile-time check)
- [x] ✓ **GREEN**: Configure boundaries:
  - `Perme8Dashboard` — `top_level?: true, deps: [], exports: []`
  - `Perme8DashboardWeb` — `top_level?: true, deps: [ExoDashboardWeb], exports: [Endpoint, Telemetry]`
  - Note: Boundary `externals_mode: :relaxed` for Phoenix/LiveView/HTML deps
- [x] ✓ **REFACTOR**: Verify boundary config matches exo_dashboard pattern

### Phase 1 Validation
- [x] ✓ App compiles without warnings
- [x] ✓ `mix boundary` passes (no violations)
- [x] ✓ Endpoint starts and responds on port 4012 (dev) / 4013 (test)

---

## Phase 2: Assets and Styling (phoenix-tdd) ✓

Set up the CSS/JS asset pipeline for perme8_dashboard, replicating the DaisyUI dark theme from exo_dashboard.

### Step 2.1: Asset Pipeline Setup

**Files to create:**
- `apps/perme8_dashboard/assets/css/app.css` — Tailwind v4 config with DaisyUI dark theme (copy from exo_dashboard, same theme)
- `apps/perme8_dashboard/assets/js/app.ts` — LiveSocket setup with ScrollToHash hook
- `apps/perme8_dashboard/assets/vendor/topbar.cjs` — (symlink or copy from exo_dashboard)
- `apps/perme8_dashboard/assets/vendor/heroicons.js` — (symlink or copy)
- `apps/perme8_dashboard/assets/vendor/daisyui.js` — (symlink or copy)
- `apps/perme8_dashboard/assets/vendor/daisyui-theme.js` — (symlink or copy)
- `apps/perme8_dashboard/assets/package.json`

**Files to modify:**
- `config/config.exs` — add `perme8_dashboard` esbuild and tailwind profiles

- [x] ✓ **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/assets_test.exs`
  - Tests: CSS file exists at expected path, JS file exists, assets compile without error
- [x] ✓ **GREEN**: Create all asset files, configure esbuild/tailwind profiles
- [x] ✓ **REFACTOR**: Deduplicate vendor files if possible (or document why copies are needed)

### Step 2.2: Root Layout with Dark Theme

**File:** `apps/perme8_dashboard/lib/perme8_dashboard_web/components/layouts/root.html.heex`

Must satisfy BDD scenarios:
- `"html" should have attribute "data-theme" with value "dark"`
- `"body" should have class "bg-base-100"`

- [x] ✓ **RED**: Write test in `apps/perme8_dashboard/test/perme8_dashboard_web/layouts_test.exs`
  - Tests: Root layout renders `data-theme="dark"` on `<html>`, `bg-base-100` on `<body>`, includes CSRF token, live title, asset links
- [x] ✓ **GREEN**: Implement root layout template (similar to exo_dashboard's but with "Perme8 Dashboard" title)
- [x] ✓ **REFACTOR**: Clean up

### Phase 2 Validation
- [x] ✓ Assets compile: `tailwind perme8_dashboard` and `esbuild perme8_dashboard` succeed
- [x] ✓ Layout tests pass
- [x] ✓ Dark theme renders correctly

---

## Phase 3: Core Components and App Layout (phoenix-tdd) ✓

### Step 3.1: Core Components

**File:** `apps/perme8_dashboard/lib/perme8_dashboard_web/components/core_components.ex`

Provide minimal core components (flash, icon, button) that match the DaisyUI dark theme. These are needed by the app layout for flash messages and the tab navigation.

- [x] ✓ **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/components/core_components_test.exs`
  - Tests: `flash/1` renders correctly, `icon/1` renders hero icon span, `button/1` renders with DaisyUI classes
- [x] ✓ **GREEN**: Implement core components (copy structure from exo_dashboard's CoreComponents, adapted for perme8_dashboard)
- [x] ✓ **REFACTOR**: Remove any unused components

### Step 3.2: Tab Navigation Component

**File:** `apps/perme8_dashboard/lib/perme8_dashboard_web/components/tab_components.ex`

Create a reusable tab navigation component that renders tabs with `data-tab` attributes. Must be extensible for future tabs (Sessions, etc.).

Must satisfy BDD scenarios:
- `"[data-tab='features']" should be visible`
- `"[data-tab='features']" should have class "tab-active"`
- `"[data-tab]" should exist`

- [x] ✓ **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/components/tab_components_test.exs`
  - Tests:
    - Renders tab bar with `data-tab` attributes
    - Active tab has `tab-active` class
    - Inactive tabs do not have `tab-active` class
    - Tabs render as navigation links with correct paths
    - Features tab links to root `/`
- [x] ✓ **GREEN**: Implement `tab_bar/1` component accepting tabs list and active_tab assign
  ```elixir
  attr :tabs, :list, required: true  # [{key, label, path}]
  attr :active_tab, :atom, required: true
  def tab_bar(assigns)
  ```
- [x] ✓ **REFACTOR**: Ensure component is reusable and extensible

### Step 3.3: App Layout with Tabbed Navigation

**File:** `apps/perme8_dashboard/lib/perme8_dashboard_web/components/layouts/app.html.heex`

Create the app layout with:
- Sidebar with "Perme8 Dashboard" branding (DaisyUI drawer pattern, similar to exo_dashboard)
- Tab navigation bar in the content area
- Content area for the active tab's view

Must satisfy BDD scenarios:
- `I should see "Perme8 Dashboard"`
- Tab navigation is visible on landing

- [x] ✓ **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/layouts/app_layout_test.exs`
  - Tests:
    - Layout renders "Perme8 Dashboard" branding
    - Layout includes tab navigation via `tab_bar` component
    - Layout renders `@inner_content`
    - Flash group is rendered
    - Drawer sidebar pattern with DaisyUI classes
- [x] ✓ **GREEN**: Implement app layout template with drawer sidebar and tab navigation
- [x] ✓ **REFACTOR**: Keep thin, delegate to components

### Phase 3 Validation
- [x] ✓ All component tests pass
- [x] ✓ Layout renders correctly with tab navigation
- [x] ✓ No boundary violations

---

## Phase 4: Router and LiveView Integration (phoenix-tdd) ✓

### Step 4.1: Router with Exo LiveView Mounts

**File:** `apps/perme8_dashboard/lib/perme8_dashboard_web/router.ex`

Configure the router to:
- Use the perme8_dashboard root layout in the browser pipeline
- Define a `live_session :dashboard` with the perme8_dashboard app layout
- Mount `ExoDashboardWeb.DashboardLive` at `/` (Features tab landing)
- Mount `ExoDashboardWeb.FeatureDetailLive` at `/features/*uri`

**Critical:** The exo LiveViews use `ExoDashboardWeb, :live_view` which pulls in `ExoDashboardWeb.CoreComponents` and `ExoDashboardWeb.Layouts`. Since we're overriding the layout at the `live_session` level, the LiveViews will render their content (via `render/1`) inside perme8_dashboard's layout. However, the `~p` sigil in exo's LiveViews references `ExoDashboardWeb.Router` — we need to ensure navigation links (like `~p"/"` for back links) work correctly. Since both routers have the same route structure (`/` and `/features/*uri`), this should work if we ensure `Perme8DashboardWeb.Router` matches the same paths.

**Alternative approach if `~p` is problematic:** The exo LiveViews use `navigate={~p"/"}` which references their own endpoint's router. When mounted under perme8_dashboard's live_session, this could cause issues. We may need to configure perme8_dashboard_web's verified routes to also use `ExoDashboardWeb.Router` paths, OR refactor exo's navigation to use raw paths instead of verified routes.

**Resolution:** Since the LiveViews are declared with `use ExoDashboardWeb, :live_view`, their verified routes point to `ExoDashboardWeb.Endpoint`. When rendered inside perme8_dashboard, navigation links should be relative to the current connection, which is on the perme8_dashboard endpoint. The `~p` sigil generates static paths at compile time that are verified against `ExoDashboardWeb.Router`. Since both routers define the same paths (`/` and `/features/*uri`), the generated paths will work correctly on either endpoint.

- [x] **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/router_test.exs`
  - Tests:
    - `GET /` returns 200 and renders DashboardLive content
    - `GET /features/some/path.feature` returns 200 and renders FeatureDetailLive content
    - Layout is from Perme8DashboardWeb (not ExoDashboardWeb)
    - Tab navigation is visible on all routes
- [x] **GREEN**: Implement router with browser pipeline and live_session
  ```elixir
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Perme8DashboardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", Perme8DashboardWeb do
    pipe_through :browser

    live_session :dashboard, layout: {Perme8DashboardWeb.Layouts, :app} do
      live "/", ExoDashboardWeb.DashboardLive, :index
      live "/features/*uri", ExoDashboardWeb.FeatureDetailLive, :show
    end
  end
  ```
  Note: We use the fully-qualified module name for the exo LiveViews since they live in a different app. The `scope` alias `Perme8DashboardWeb` won't affect them because they're specified with their full module path.
- [x] **REFACTOR**: Verify route helpers work correctly

### Step 4.2: Perme8DashboardWeb Module

**File:** `apps/perme8_dashboard/lib/perme8_dashboard_web.ex`

Configure the web module with proper verified routes, html helpers, and imports. The key consideration is that this module defines how `use Perme8DashboardWeb, :live_view` etc. work, but the exo LiveViews use `use ExoDashboardWeb, :live_view`. The perme8_dashboard_web module is primarily for its own layouts and components.

- [x] **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/web_module_test.exs`
  - Tests: Module defines `:router`, `:controller`, `:live_view`, `:html` functions
- [x] **GREEN**: Implement `Perme8DashboardWeb` module following exo_dashboard pattern
- [x] **REFACTOR**: Ensure imports/aliases are minimal and correct

### Step 4.3: DashboardLive Integration Test

Test that exo's DashboardLive renders correctly inside perme8_dashboard's layout.

- [x] **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/live/dashboard_live_test.exs`
  - Uses `Perme8DashboardWeb.ConnCase` with `@endpoint Perme8DashboardWeb.Endpoint`
  - Tests (mapping to BDD scenarios):
    - Dashboard landing page shows "Perme8 Dashboard" in layout
    - `[data-tab='features']` is visible and has `tab-active` class
    - `[data-feature-tree]` wrapper is visible (we add this data attr to the app layout's content area)
    - Feature tree displays apps with `[data-app]` elements
    - App groups show feature and scenario counts
    - Adapter filter buttons are displayed (`[data-filter='all']`, `[data-filter='browser']`, etc.)
    - Filtering by adapter shows only matching features
    - "All" filter resets to show every feature
    - Clicking a feature navigates to feature detail with URL containing `/features/`
    - Feature detail shows scenarios with "Given"/"Then" steps
    - Back navigation returns to feature list
    - Tab navigation supports additional tabs (multiple `[data-tab]` elements exist)
- [x] **GREEN**: Ensure router, layout, and LiveView integration work end-to-end
- [x] **REFACTOR**: DRY up test setup (mock catalog injection)

### Phase 4 Validation
- [x] All router tests pass
- [x] All LiveView integration tests pass
- [x] Exo LiveViews render correctly inside perme8_dashboard layout
- [x] Navigation between feature list and detail works
- [x] Filter buttons work correctly

---

## Phase 5: Exo Dashboard Layout Migration (phoenix-tdd) ✓

### Step 5.1: Strip Exo Dashboard App Layout

**File to modify:** `apps/exo_dashboard/lib/exo_dashboard_web/components/layouts/app.html.heex`

Replace the drawer/sidebar/topbar layout with a minimal pass-through that just renders content. This satisfies the BDD scenario: `".drawer" should not exist`.

Must satisfy BDD scenario in `apps/exo_dashboard/test/features/dashboard.browser.feature`:
- "Exo Dashboard serves layout-less views after migration"
  - `I should see "feature"`
  - `".drawer" should not exist`

- [x] **RED**: Write/update test `apps/exo_dashboard/test/exo_dashboard_web/live/dashboard_live_test.exs`
  - Add new test: "renders without drawer layout chrome"
    - Assert `.drawer` CSS class is NOT present in rendered HTML
    - Assert content still renders (features visible)
    - Assert "Exo Dashboard" header text still appears (from DashboardLive's render, not layout)
- [x] **GREEN**: Replace `app.html.heex` content:
  ```heex
  <main class="flex-1 flex flex-col p-4 lg:p-8 overflow-y-auto">
    <div class="w-full max-w-5xl mx-auto">
      {@inner_content}
    </div>
  </main>
  <.flash_group flash={@flash} />
  ```
  This removes the drawer, sidebar, and topbar while keeping the content wrapper and flash messages.
- [x] **REFACTOR**: Verify all existing exo_dashboard tests still pass

### Step 5.2: Verify Exo Dashboard Standalone Still Works

The exo_dashboard should still be usable standalone (port 4010) with its root layout providing the HTML skeleton. It just won't have the sidebar/topbar chrome.

- [x] **RED**: Write test `apps/exo_dashboard/test/exo_dashboard_web/live/standalone_test.exs`
  - Tests:
    - Dashboard loads on exo endpoint (port 4011 in test)
    - Content renders without drawer
    - Feature list is functional
    - Navigation to feature detail works
    - Back navigation works
- [x] **GREEN**: Ensure exo_dashboard root layout + minimal app layout provides a usable standalone experience
- [x] **REFACTOR**: Clean up any layout references in exo_dashboard

### Step 5.3: Add Data Attributes for BDD Scenarios

Several BDD scenarios reference data attributes that don't currently exist in the exo LiveViews:
- `data-feature-tree` — needs to be on the feature tree container
- `data-feature-detail` — needs to be on the feature detail container

**Files to modify:**
- `apps/exo_dashboard/lib/exo_dashboard_web/live/dashboard_live.ex` — add `data-feature-tree` wrapper
- `apps/exo_dashboard/lib/exo_dashboard_web/live/feature_detail_live.ex` — add `data-feature-detail` attribute

Also, the perme8_dashboard app layout should wrap the inner content in a container that has the `data-feature-tree` visible when on the features tab.

- [x] **RED**: Write test assertions in `apps/perme8_dashboard/test/perme8_dashboard_web/live/dashboard_live_test.exs`
  - Assert `[data-feature-tree]` exists when feature list is rendered
  - Assert `[data-feature-detail]` exists when feature detail is rendered
- [x] **GREEN**: Add data attributes to exo LiveView templates:
  - DashboardLive: wrap feature tree output in `<div data-feature-tree>...</div>`
  - FeatureDetailLive: add `data-feature-detail` to the `#feature-detail` div
- [x] **REFACTOR**: Ensure attributes don't break existing exo_dashboard tests

### Phase 5 Validation
- [x] Exo dashboard layout chrome is removed (no `.drawer`)
- [x] All existing exo_dashboard tests pass
- [x] Exo standalone mode still functional
- [x] Data attributes added for BDD scenario selectors
- [x] All perme8_dashboard integration tests still pass

---

## Phase 6: Full Integration and BDD Readiness (phoenix-tdd) ✓

### Step 6.1: End-to-End LiveView Tests

Comprehensive integration tests that verify the full flow matches all BDD browser scenarios.

- [x] **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/live/full_flow_test.exs`
  - Tests mapping to each BDD browser scenario:
    1. Landing page shows "Perme8 Dashboard" with active Features tab
    2. Features tab displays feature tree on landing
    3. Feature list displays app groups with feature/scenario counts
    4. Filter buttons visible (all, browser, http, security, cli)
    5. Filtering by adapter type shows only matching features
    6. "All" filter resets to show every feature
    7. Clicking a feature navigates to feature detail (URL contains `/features/`)
    8. Feature detail shows scenarios and steps (Given/Then)
    9. Back navigation returns to feature list
    10. Tab navigation supports additional tabs
    11. Dashboard uses DaisyUI dark theme (data-theme="dark", bg-base-100)
- [x] **GREEN**: Fix any remaining issues to make all tests pass
- [x] **REFACTOR**: DRY up test helpers

### Step 6.2: Security Headers

Ensure the endpoint is configured with proper security headers for BDD security scenarios.

- [x] **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/security_test.exs`
  - Tests:
    - content-security-policy with frame-ancestors 'self' (Phoenix 1.8+ replacement for X-Frame-Options)
    - X-Content-Type-Options header is "nosniff"
    - cache-control header is present
- [x] **GREEN**: Verify `put_secure_browser_headers` plug is in the pipeline (it sets CSP and X-Content-Type-Options by default)
- [x] **REFACTOR**: Tests aligned to Phoenix 1.8 security header defaults

### Step 6.3: BDD Feature Files

Create the BDD feature files that define the acceptance criteria. These files are already specified in the ticket.

**Files to create:**
- `apps/perme8_dashboard/test/features/dashboard/dashboard.browser.feature`
- `apps/perme8_dashboard/test/features/dashboard/dashboard.security.feature`

**File to update:**
- `apps/exo_dashboard/test/features/dashboard.browser.feature` — add the "layout-less views after migration" scenario (already present per the ticket)

- [x] Create BDD feature files with content matching the ticket specification
- [x] Verify feature file paths follow the `test/features/<context>/<name>.<adapter>.feature` convention

### Phase 6 Validation
- [x] All end-to-end LiveView tests pass
- [x] Security header tests pass
- [x] BDD feature files created and parseable

---

## Phase 7: Pre-commit and Final Validation ✓

### Step 7.1: Pre-commit Checkpoint

- [x] `mix compile --warnings-as-errors` passes for all apps
- [x] `mix boundary` passes with no violations (via `mix precommit`)
- [x] `mix format --check-formatted` passes
- [x] `mix credo --strict` passes
- [x] `mix test` passes (all apps)
- [x] `mix precommit` passes end-to-end

### Step 7.2: Documentation Updates

- [x] Update `docs/umbrella_apps.md` to include `perme8_dashboard` in the apps table:
  ```
  | `perme8_dashboard` | Phoenix (dev tool) | 4012 / 4013 | Unified dev-tool dashboard — mounts Exo Dashboard views and future tool tabs |
  ```
- [x] Update dependency graph to show `perme8_dashboard -> exo_dashboard`

---

## Implementation Notes

### File Structure for New App

```
apps/perme8_dashboard/
├── assets/
│   ├── css/
│   │   └── app.css                    # Tailwind v4 + DaisyUI dark theme
│   ├── js/
│   │   └── app.ts                     # LiveSocket + ScrollToHash hook
│   ├── vendor/
│   │   ├── topbar.cjs
│   │   ├── heroicons.js
│   │   ├── daisyui.js
│   │   └── daisyui-theme.js
│   └── package.json
├── lib/
│   ├── perme8_dashboard.ex                        # Root boundary
│   ├── perme8_dashboard/
│   │   └── application.ex                          # OTP app (starts Endpoint)
│   └── perme8_dashboard_web/
│       ├── components/
│       │   ├── core_components.ex                  # Flash, icon, button
│       │   ├── tab_components.ex                   # Tab navigation
│       │   ├── layouts.ex                          # Layout module
│       │   └── layouts/
│       │       ├── root.html.heex                  # HTML skeleton (dark theme)
│       │       └── app.html.heex                   # App layout with tabs
│       ├── controllers/
│       │   └── error_html.ex                       # Error pages
│       ├── endpoint.ex                             # Phoenix Endpoint (port 4012/4013)
│       ├── gettext.ex                              # i18n
│       ├── router.ex                               # Routes mounting exo LiveViews
│       └── telemetry.ex                            # Telemetry
│   └── perme8_dashboard_web.ex                     # Web module (router/controller/html macros)
├── mix.exs
├── priv/
│   └── static/                                     # Compiled assets
├── test/
│   ├── features/
│   │   └── dashboard/
│   │       ├── dashboard.browser.feature
│   │       └── dashboard.security.feature
│   ├── perme8_dashboard_web/
│   │   ├── components/
│   │   │   ├── core_components_test.exs
│   │   │   └── tab_components_test.exs
│   │   ├── layouts/
│   │   │   └── app_layout_test.exs
│   │   ├── live/
│   │   │   ├── dashboard_live_test.exs
│   │   │   └── full_flow_test.exs
│   │   ├── assets_test.exs
│   │   ├── config_test.exs
│   │   ├── endpoint_test.exs
│   │   ├── router_test.exs
│   │   ├── security_test.exs
│   │   └── web_module_test.exs
│   ├── support/
│   │   └── conn_case.ex
│   └── test_helper.exs
```

### Files Modified in exo_dashboard

```
apps/exo_dashboard/
├── lib/
│   └── exo_dashboard_web/
│       ├── components/
│       │   └── layouts/
│       │       └── app.html.heex          # MODIFIED: Remove drawer/sidebar/topbar
│       └── live/
│           ├── dashboard_live.ex          # MODIFIED: Add data-feature-tree attr
│           └── feature_detail_live.ex     # MODIFIED: Add data-feature-detail attr
├── test/
│   ├── features/
│   │   └── dashboard.browser.feature     # MODIFIED: Add layout-less scenario (already present)
│   └── exo_dashboard_web/
│       └── live/
│           ├── dashboard_live_test.exs   # MODIFIED: Add no-drawer assertion
│           └── standalone_test.exs       # NEW: Verify standalone still works
```

### Config Files Modified

```
config/
├── config.exs     # Add perme8_dashboard endpoint, esbuild, tailwind profiles
├── dev.exs        # Add perme8_dashboard dev endpoint (port 4012)
└── test.exs       # Add perme8_dashboard test endpoint (port 4013)
```

### Key Design Decisions

1. **Tab component is data-driven**: The tab bar accepts a list of tab definitions, making it trivial to add the Sessions tab later.

2. **Exo LiveViews are mounted directly**: No `live_render` / `live_component` wrapping. The router's `live_session` sets the layout to perme8_dashboard's app layout, and the exo LiveViews render their content within that layout.

3. **Verified routes (`~p`)**: The exo LiveViews compile their `~p` paths against `ExoDashboardWeb.Router`. Since both routers define the same path structure, the generated paths work on either endpoint. No changes to exo LiveViews' navigation code are needed.

4. **Asset independence**: perme8_dashboard has its own CSS/JS pipeline with its own DaisyUI theme. It does NOT share assets with exo_dashboard at build time, but uses the same visual theme.

5. **No domain layer**: perme8_dashboard is purely an interface app. It has no domain entities, policies, use cases, or infrastructure. All business logic remains in `exo_dashboard`.

6. **Dev-only**: Not included in the `releases` block in root `mix.exs`.

### Risk Mitigations

| Risk | Mitigation |
|------|-----------|
| Exo `~p` routes don't work under perme8 endpoint | Both routers define identical paths; `~p` generates static strings at compile time |
| Exo CoreComponents conflict with Perme8 CoreComponents | No conflict — exo LiveViews import `ExoDashboardWeb.CoreComponents` via their `use ExoDashboardWeb, :live_view`; the layout uses `Perme8DashboardWeb.CoreComponents` |
| CSS class conflicts between exo components and perme8 layout | Both use the same DaisyUI dark theme with identical color tokens |
| ScrollToHash hook not available in perme8_dashboard | Copy the hook into perme8_dashboard's `app.ts` |
| Exo standalone mode breaks after layout migration | Verified by Step 5.2 standalone tests; root.html.heex unchanged |

---

## Testing Strategy

- **Total estimated tests**: ~45-55
- **Distribution**:
  - Phase 1 (Scaffold): ~5 tests (endpoint, config, boundary)
  - Phase 2 (Assets/Layouts): ~5 tests (asset compilation, root layout)
  - Phase 3 (Components): ~10 tests (core components, tab component, app layout)
  - Phase 4 (Router/Integration): ~12 tests (router, LiveView integration, navigation)
  - Phase 5 (Exo Migration): ~8 tests (layout removal, standalone, data attrs)
  - Phase 6 (End-to-End): ~15 tests (full flow, security headers)

### Test Types

| Layer | Test Case Module | Async? | Notes |
|-------|-----------------|--------|-------|
| Components | `ExUnit.Case` | Yes | Pure component rendering |
| Layouts | `Perme8DashboardWeb.ConnCase` | Yes | Template rendering |
| LiveView | `Perme8DashboardWeb.ConnCase` | No | Requires mock catalog injection via Application env |
| Router | `Perme8DashboardWeb.ConnCase` | Yes | Route matching |
| Security | `Perme8DashboardWeb.ConnCase` | Yes | Header assertions |
| Exo Migration | `ExoDashboardWeb.ConnCase` | No | Requires mock catalog |

### Mock Strategy

The exo LiveViews use `Application.get_env(:exo_dashboard, :test_catalog)` to inject mock data. Tests in perme8_dashboard will use the same mechanism:

```elixir
setup do
  Application.put_env(:exo_dashboard, :test_catalog, @mock_catalog)
  on_exit(fn -> Application.delete_env(:exo_dashboard, :test_catalog) end)
  :ok
end
```

This is set on `:exo_dashboard` (not `:perme8_dashboard`) because the LiveView code lives in `exo_dashboard` and reads from that app's config.
