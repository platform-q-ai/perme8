defmodule AgentsWeb do
  @moduledoc """
  The entrypoint for defining the Agents web interface.

  Provides LiveViews for agent-related features (sessions, etc.)
  that can be mounted in the Perme8 Dashboard or run standalone.
  """

  use Boundary,
    deps: [
      Agents,
      Agents.Domain,
      Agents.Sessions,
      Agents.Sessions.Domain,
      Agents.Tickets,
      Agents.Tickets.Domain,
      Identity,
      IdentityWeb,
      Jarga,
      Jarga.Accounts,
      Perme8.Events
    ],
    exports: [
      Endpoint,
      Telemetry,
      AnalyticsLive.Index,
      DashboardLive.Index,
      AgentsLive.Index,
      AgentsLive.Form
    ]

  def static_paths do
    ~w(assets fonts images favicon.ico robots.txt)
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: AgentsWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Gettext, backend: AgentsWeb.Gettext

      import Phoenix.HTML
      import AgentsWeb.CoreComponents

      alias Phoenix.LiveView.JS
      alias AgentsWeb.Layouts

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AgentsWeb.Endpoint,
        router: AgentsWeb.Router,
        statics: AgentsWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
