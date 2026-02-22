defmodule ExoDashboardWeb.Router do
  use ExoDashboardWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ExoDashboardWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  if Application.compile_env(:exo_dashboard, :basic_auth_enabled) do
    pipeline :basic_auth do
      plug(:dashboard_basic_auth)
    end

    defp dashboard_basic_auth(conn, _opts) do
      username = Application.get_env(:jarga, :dashboard_username)
      password = Application.get_env(:jarga, :dashboard_password)

      if username && password do
        Plug.BasicAuth.basic_auth(conn, username: username, password: password)
      else
        conn
        |> send_resp(503, "Dashboard authentication not configured")
        |> halt()
      end
    end
  end

  # Health endpoint is always unauthenticated (load balancer checks)
  scope "/", ExoDashboardWeb do
    pipe_through(:browser)

    get("/health", HealthController, :index)
  end

  scope "/", ExoDashboardWeb do
    if Application.compile_env(:exo_dashboard, :basic_auth_enabled) do
      pipe_through([:browser, :basic_auth])
    else
      pipe_through(:browser)
    end

    live_session :dashboard, layout: {ExoDashboardWeb.Layouts, :app} do
      live("/", DashboardLive, :index)
      live("/features/*uri", FeatureDetailLive, :show)
    end
  end
end
