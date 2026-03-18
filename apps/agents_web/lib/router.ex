defmodule AgentsWeb.Router do
  use AgentsWeb, :router

  import AgentsWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AgentsWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
  end

  # Health check endpoint (no auth required) for exo-bdd server readiness probes
  scope "/" do
    get("/health", AgentsWeb.HealthController, :index)
  end

  scope "/", AgentsWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :agents,
      on_mount: [{AgentsWeb.UserAuth, :require_authenticated}] do
      live("/agents", AgentsLive.Index, :index)
      live("/agents/new", AgentsLive.Form, :new)
      live("/agents/:id/view", AgentsLive.Form, :view)
      live("/agents/:id/edit", AgentsLive.Form, :edit)
    end

    live_session :sessions,
      on_mount: [{AgentsWeb.UserAuth, :require_authenticated}] do
      live("/sessions", DashboardLive.Index, :index)
      live("/analytics", AnalyticsLive.Index, :index)
    end
  end
end
