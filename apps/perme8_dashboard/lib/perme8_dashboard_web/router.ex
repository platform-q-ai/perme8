defmodule Perme8DashboardWeb.Router do
  use Perme8DashboardWeb, :router

  import Perme8DashboardWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {Perme8DashboardWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
  end

  if Application.compile_env(:perme8_dashboard, :basic_auth_enabled) do
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

  pipeline :require_auth do
    plug(:require_authenticated_user)
  end

  # Health endpoint is always unauthenticated (load balancer checks)
  scope "/", Perme8DashboardWeb do
    pipe_through(:browser)

    get("/health", HealthController, :index)
  end

  scope "/" do
    if Application.compile_env(:perme8_dashboard, :basic_auth_enabled) do
      pipe_through([:browser, :basic_auth])
    else
      pipe_through(:browser)
    end

    # Features (no auth required — uses mount_current_scope for optional user info)
    live_session :dashboard,
      layout: {Perme8DashboardWeb.Layouts, :app},
      on_mount: [
        {Perme8DashboardWeb.Hooks.SetActiveTab, :default},
        {Perme8DashboardWeb.UserAuth, :mount_current_scope}
      ] do
      live("/", ExoDashboardWeb.DashboardLive, :index)
      live("/features/*uri", ExoDashboardWeb.FeatureDetailLive, :show)
    end
  end

  # Sessions (requires Identity auth — uses AgentsWeb.DashboardLive.Index directly)
  scope "/" do
    if Application.compile_env(:perme8_dashboard, :basic_auth_enabled) do
      pipe_through([:browser, :basic_auth, :require_auth])
    else
      pipe_through([:browser, :require_auth])
    end

    live_session :dashboard_authenticated,
      layout: {Perme8DashboardWeb.Layouts, :app},
      on_mount: [
        {Perme8DashboardWeb.Hooks.SetActiveTab, :default},
        {Perme8DashboardWeb.UserAuth, :require_authenticated}
      ] do
      live("/sessions", AgentsWeb.DashboardLive.Index, :index)
    end
  end
end
