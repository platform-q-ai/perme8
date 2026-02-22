defmodule AgentsWeb.UserAuthTest do
  use AgentsWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Identity.Domain.Scope
  alias AgentsWeb.UserAuth

  import Jarga.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, AgentsWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn}
  end

  describe "fetch_current_scope_for_user/2" do
    test "authenticates user from session", %{conn: conn, user: user} do
      user_token = Jarga.Accounts.generate_user_session_token(user)

      conn =
        conn
        |> put_session(:user_token, user_token)
        |> UserAuth.fetch_current_scope_for_user([])

      assert conn.assigns.current_scope.user.id == user.id
    end

    test "assigns nil scope when no token in session", %{conn: conn} do
      conn = UserAuth.fetch_current_scope_for_user(conn, [])
      assert conn.assigns.current_scope == Scope.for_user(nil)
    end

    test "assigns nil scope when token is invalid", %{conn: conn} do
      conn =
        conn
        |> put_session(:user_token, "invalid-token")
        |> UserAuth.fetch_current_scope_for_user([])

      assert conn.assigns.current_scope == Scope.for_user(nil)
    end
  end

  describe "require_authenticated_user/2" do
    test "redirects when user is not authenticated", %{conn: conn} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_user(nil))
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      assert redirected_to(conn) =~ "/users/log-in"
    end

    test "includes return_to parameter in redirect", %{conn: conn} do
      conn =
        %{conn | request_path: "/sessions"}
        |> assign(:current_scope, Scope.for_user(nil))
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      location = redirected_to(conn)
      assert location =~ "return_to="
    end

    test "does not redirect when user is authenticated", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_user(user))
        |> UserAuth.require_authenticated_user([])

      refute conn.halted
    end
  end

  describe "on_mount :mount_current_scope" do
    test "assigns current_scope based on a valid user_token", %{conn: conn, user: user} do
      user_token = Jarga.Accounts.generate_user_session_token(user)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.user.id == user.id
    end

    test "assigns nil scope when no user_token in session", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      # Scope.for_user(nil) returns nil
      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_authenticated" do
    test "continues when user_token is valid", %{conn: conn, user: user} do
      user_token = Jarga.Accounts.generate_user_session_token(user)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:require_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.user.id == user.id
    end

    test "halts and redirects when user_token is invalid", %{conn: conn} do
      session = conn |> put_session(:user_token, "bad-token") |> get_session()

      socket = %LiveView.Socket{
        endpoint: AgentsWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        UserAuth.on_mount(:require_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_scope == nil
    end

    test "halts and redirects when no user_token in session", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: AgentsWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        UserAuth.on_mount(:require_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_scope == nil
    end
  end
end
