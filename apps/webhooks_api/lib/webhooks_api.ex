defmodule WebhooksApi do
  @moduledoc """
  The JSON API application for Webhooks.

  This app owns the REST API surface: endpoint, router, controllers,
  JSON views, auth plug, and API-specific configuration.

  It depends on:
  - `Webhooks` context for domain logic
  - `Identity` for API key verification and user lookup
  """

  use Boundary,
    deps: [
      Identity,
      WebhooksApi.Repo
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
        endpoint: WebhooksApi.Endpoint,
        router: WebhooksApi.Router,
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
