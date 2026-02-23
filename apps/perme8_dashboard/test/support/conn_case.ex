defmodule Perme8DashboardWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Includes database sandbox setup for tests that render LiveViews
  which access the database (e.g., sessions from Agents).
  """
  use ExUnit.CaseTemplate

  alias Identity.Domain.Scope

  using do
    quote do
      @endpoint Perme8DashboardWeb.Endpoint

      use Perme8DashboardWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Perme8DashboardWeb.ConnCase
    end
  end

  setup tags do
    Jarga.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = Jarga.AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    %{conn: log_in_user(conn, user), user: user, scope: scope}
  end

  @doc """
  Logs the given `user` into the `conn`.

  Uses Identity's session token so the shared `_identity_key` cookie
  is populated correctly for the dashboard's `fetch_current_scope_for_user` plug.
  """
  def log_in_user(conn, user) do
    token = Identity.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
