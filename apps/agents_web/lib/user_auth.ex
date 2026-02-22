defmodule AgentsWeb.UserAuth do
  @moduledoc """
  Authentication helpers for AgentsWeb LiveViews.

  Provides `on_mount` callbacks for authenticating users via session tokens.
  Delegates to `Jarga.Accounts` for token validation.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Jarga.Accounts
  alias Identity.Domain.Scope

  @doc """
  Plug for fetching the current scope from the session.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    with token when is_binary(token) <- get_session(conn, :user_token),
         {user, _inserted_at} <- Accounts.get_user_by_session_token(token) do
      assign(conn, :current_scope, Scope.for_user(user))
    else
      _ -> assign(conn, :current_scope, Scope.for_user(nil))
    end
  end

  @doc """
  Plug that requires the user to be authenticated.
  Redirects to the login page on jarga_web if not authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/users/log-in")
      |> halt()
    end
  end

  @doc """
  LiveView on_mount callback for mounting the current scope.
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: "/users/log-in")

      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      {user, _} =
        if user_token = session["user_token"] do
          Accounts.get_user_by_session_token(user_token)
        end || {nil, nil}

      Scope.for_user(user)
    end)
  end
end
