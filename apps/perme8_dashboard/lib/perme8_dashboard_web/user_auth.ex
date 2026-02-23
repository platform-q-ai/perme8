defmodule Perme8DashboardWeb.UserAuth do
  @moduledoc """
  Authentication helpers for Perme8Dashboard LiveViews.

  Provides plugs and `on_mount` callbacks for authenticating users via
  Identity session tokens. Shares the `_identity_key` session cookie with
  Identity so users authenticated there are also authenticated here.

  When unauthenticated, redirects to the Identity app's login page.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Identity
  alias Identity.Domain.Scope

  @doc """
  Plug for fetching the current scope from the session.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    with token when is_binary(token) <- get_session(conn, :user_token),
         {user, _inserted_at} <- Identity.get_user_by_session_token(token) do
      assign(conn, :current_scope, Scope.for_user(user))
    else
      _ -> assign(conn, :current_scope, nil)
    end
  end

  @doc """
  Plug that requires the user to be authenticated.
  Redirects to Identity's login page if not authenticated,
  including the current URL as a `return_to` parameter so the
  user is sent back after login.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      conn
    else
      return_to = Perme8DashboardWeb.Endpoint.url() <> current_path(conn)

      conn
      |> redirect(external: identity_login_url(return_to))
      |> halt()
    end
  end

  @doc """
  LiveView on_mount callbacks:

    * `:mount_current_scope` — mounts the scope without requiring auth
    * `:require_authenticated` — requires an authenticated user, redirects if not
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      {:cont, socket}
    else
      # The :require_authenticated_user plug handles the initial HTTP request
      # with a proper return_to URL. This on_mount only fires on WebSocket
      # reconnect (e.g. expired session mid-use), so a simple redirect suffices.
      return_to = Perme8DashboardWeb.Endpoint.url() <> "/sessions"

      socket = Phoenix.LiveView.redirect(socket, external: identity_login_url(return_to))
      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      {user, _} =
        if user_token = session["user_token"] do
          Identity.get_user_by_session_token(user_token)
        end || {nil, nil}

      Scope.for_user(user)
    end)
  end

  defp identity_login_url(return_to) do
    identity_url =
      Application.get_env(:perme8_dashboard, :identity_url) || IdentityWeb.Endpoint.url()

    base = identity_url <> "/users/log-in"

    if return_to do
      base <> "?" <> URI.encode_query(%{"return_to" => return_to})
    else
      base
    end
  end
end
