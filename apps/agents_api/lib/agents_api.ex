defmodule AgentsApi do
  @moduledoc """
  The JSON API application for Agents.

  This app owns the REST API surface for agent management: endpoint, router,
  controllers, JSON views, auth plug, and API-specific logic.

  It depends on:
  - `Agents` context for agent domain operations
  - `Identity` for API key verification and user lookup
  """

  # API interface layer - depends on Agents context and Identity for auth
  use Boundary,
    top_level?: true,
    deps: [
      Agents,
      Identity
    ],
    exports: [Endpoint]

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AgentsApi.Endpoint,
        router: AgentsApi.Router,
        statics: []
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/router/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
