defmodule IdentityWeb.Router do
  @moduledoc """
  Router for the Identity application.

  Handles all authentication-related routes including:
  - User registration
  - Login/logout
  - Password management
  - Email verification
  - API key management
  """

  use IdentityWeb, :router

  import IdentityWeb.Plugs.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IdentityWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers

    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes (no authentication required)
  scope "/", IdentityWeb do
    pipe_through [:browser]

    # Session controller for form submissions
    post "/users/log-in", SessionController, :create
    delete "/users/log-out", SessionController, :delete
  end

  # Public LiveView routes (accessible without authentication)
  scope "/", IdentityWeb do
    pipe_through [:browser]

    live_session :public,
      on_mount: [{IdentityWeb.Plugs.UserAuth, :mount_current_scope}] do
      live "/users/register", RegistrationLive, :new
      live "/users/log-in", LoginLive, :new
      live "/users/log-in/:token", ConfirmationLive, :new
      live "/users/reset-password", ForgotPasswordLive, :new
      live "/users/reset-password/:token", ResetPasswordLive, :new
    end
  end

  # Authenticated routes (require login)
  scope "/", IdentityWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Password update form submission
    post "/users/update-password", SessionController, :update_password

    live_session :authenticated,
      on_mount: [{IdentityWeb.Plugs.UserAuth, :require_authenticated}] do
      live "/users/settings", SettingsLive, :edit
      live "/users/settings/confirm-email/:token", SettingsLive, :confirm_email
      live "/users/settings/api-keys", ApiKeysLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:identity, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: IdentityWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
