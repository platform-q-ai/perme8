defmodule JargaWeb.Router do
  use JargaWeb, :router

  import JargaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JargaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug JargaWeb.Plugs.ApiAuthPlug
  end

  scope "/", JargaWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API routes with API key authentication
  scope "/api", JargaWeb do
    pipe_through :api_authenticated

    get "/workspaces", WorkspaceApiController, :index
    get "/workspaces/:slug", WorkspaceApiController, :show

    # Project endpoints
    post "/workspaces/:workspace_slug/projects", ProjectApiController, :create
    get "/workspaces/:workspace_slug/projects/:slug", ProjectApiController, :show
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:jarga, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: JargaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # LiveDashboard for production with HTTP Basic Auth
  if Application.compile_env(:jarga, :live_dashboard_in_prod) do
    import Phoenix.LiveDashboard.Router

    pipeline :admin_basic_auth do
      plug :basic_auth
    end

    defp basic_auth(conn, _opts) do
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

    scope "/admin" do
      pipe_through [:browser, :admin_basic_auth]

      live_dashboard "/dashboard", metrics: JargaWeb.Telemetry
    end
  end

  ## App routes (authenticated)

  scope "/app", JargaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :app,
      on_mount: [
        {JargaWeb.Live.Hooks.AllowEctoSandbox, :default},
        {JargaWeb.UserAuth, :require_authenticated},
        {JargaWeb.NotificationsLive.OnMount, :default}
      ] do
      live "/", AppLive.Dashboard, :index
      live "/agents", AppLive.Agents.Index, :index
      live "/agents/new", AppLive.Agents.Form, :new
      live "/agents/:id/view", AppLive.Agents.Form, :view
      live "/agents/:id/edit", AppLive.Agents.Form, :edit
      live "/workspaces", AppLive.Workspaces.Index, :index
      live "/workspaces/new", AppLive.Workspaces.New, :new
      live "/workspaces/:workspace_slug/edit", AppLive.Workspaces.Edit, :edit
      live "/workspaces/:workspace_slug/projects/:project_slug/edit", AppLive.Projects.Edit, :edit
      live "/workspaces/:workspace_slug/projects/:project_slug", AppLive.Projects.Show, :show
      live "/workspaces/:workspace_slug/documents/:document_slug", AppLive.Documents.Show, :show
      live "/workspaces/:slug", AppLive.Workspaces.Show, :show
    end
  end

  ## Authentication routes

  scope "/", JargaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {JargaWeb.Live.Hooks.AllowEctoSandbox, :default},
        {JargaWeb.UserAuth, :require_authenticated},
        {JargaWeb.NotificationsLive.OnMount, :default}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/settings/api-keys", ApiKeysLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", JargaWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {JargaWeb.Live.Hooks.AllowEctoSandbox, :default},
        {JargaWeb.UserAuth, :mount_current_scope}
      ] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
