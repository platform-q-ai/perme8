defmodule AgentsWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use Boundary,
    top_level?: true,
    deps: [
      AgentsWeb,
      Identity,
      Jarga.Accounts,
      Jarga.Chat,
      Jarga.DataCase,
      Jarga.AccountsFixtures,
      Jarga.ChatFixtures,
      Agents.SessionsFixtures
    ],
    exports: []

  use ExUnit.CaseTemplate

  alias Identity.Domain.Scope

  using do
    quote do
      # The default endpoint for testing
      @endpoint AgentsWeb.Endpoint

      use AgentsWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import AgentsWeb.ConnCase
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
  def register_and_log_in_user(%{conn: conn} = context) do
    user = Jarga.AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user, opts \\ []) do
    token = Jarga.Accounts.generate_user_session_token(user)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    Jarga.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end
end
