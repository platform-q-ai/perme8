defmodule JargaApi do
  @moduledoc """
  The JSON API application for Jarga.

  This app owns the entire REST API surface: endpoint, router, controllers,
  JSON views, auth plug, and API-specific use cases and domain logic.

  It depends on:
  - `Jarga` contexts (Workspaces, Projects, Documents) for domain data
  - `Identity` for API key verification and user lookup
  """

  # API interface layer - depends on Jarga contexts and Identity for auth
  use Boundary,
    deps: [
      Jarga.Workspaces,
      Jarga.Projects,
      Jarga.Documents,
      Jarga.Documents.Notes.Domain,
      Identity,
      JargaApi.Accounts
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
        endpoint: JargaApi.Endpoint,
        router: JargaApi.Router,
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
