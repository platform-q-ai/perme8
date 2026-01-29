defmodule JargaWeb.Presentation do
  @moduledoc """
  Presentation layer definition for the JargaWeb application.

  The presentation layer is the outermost layer in Clean Architecture,
  responsible for handling user interface concerns and HTTP interactions.

  ## Presentation Layer Principles

  The presentation layer:

  - Handles HTTP requests and responses
  - Renders HTML views and JSON responses
  - Manages user sessions and authentication state
  - Delegates business logic to core application contexts
  - NEVER contains business rules or domain logic

  ## JargaWeb Structure

  ### Controllers (`JargaWeb.Controllers.*`)
  - Handle HTTP requests for traditional page loads
  - Coordinate authentication flows
  - Render JSON API responses

  ### LiveViews (`JargaWeb.Live.*`)
  - Handle real-time interactive UI
  - Manage client-side state
  - Subscribe to PubSub events for live updates

  ### Components (`JargaWeb.Components.*`)
  - Reusable UI components (CoreComponents)
  - Layouts for page structure
  - Form helpers and inputs

  ### Plugs (`JargaWeb.Plugs.*`)
  - Request/response transformations
  - Authentication middleware
  - Rate limiting, CORS, etc.

  ### Router (`JargaWeb.Router`)
  - Route definitions and pipelines
  - Scope-based authentication requirements

  ### Endpoint (`JargaWeb.Endpoint`)
  - Phoenix endpoint configuration
  - Static file serving
  - WebSocket handling

  ## Dependency Rules

  The presentation layer:
  - MAY depend on core contexts (Jarga.Accounts, Jarga.Workspaces, etc.)
  - MAY use Phoenix/LiveView framework modules
  - MUST NOT be depended upon by core contexts
  - MUST NOT contain business logic (delegate to use cases)
  - MUST NOT directly access Repo (use context public APIs)

  ## Boundary Configuration

  The boundary is defined in `JargaWeb` module with:
  - Depends on: All core Jarga contexts (Accounts, Workspaces, etc.)
  - Exports: Endpoint, Telemetry (for umbrella integration)

  See `JargaWeb` module for the actual boundary definition.
  """

  use Boundary,
    deps: [JargaWeb],
    exports: []

  # This is a namespace module for documentation and boundary definition.
  # The actual presentation layer boundary is defined in JargaWeb module.
end
