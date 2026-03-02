defmodule ChatWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Chat LiveView tests render through JargaWeb.Endpoint since the
  chat panel is embedded in jarga_web's admin layout. We reference
  JargaWeb modules directly (not via `use JargaWeb`) to avoid a
  compile-time circular dependency (jarga_web -> chat_web -> jarga_web).
  """

  use Boundary,
    top_level?: true,
    deps: [
      Identity,
      Jarga.Accounts,
      Jarga.DataCase,
      Jarga.AccountsFixtures,
      Chat,
      ChatWeb,
      Agents
    ],
    exports: []

  use ExUnit.CaseTemplate

  alias Identity.Domain.Scope

  using do
    quote do
      # Chat LiveViews render through JargaWeb.Endpoint (available at umbrella runtime)
      @endpoint JargaWeb.Endpoint

      # Use Phoenix.VerifiedRoutes directly to avoid compile-time dep on JargaWeb
      use Phoenix.VerifiedRoutes,
        endpoint: JargaWeb.Endpoint,
        router: JargaWeb.Router,
        statics: ~w(assets fonts images favicon.ico robots.txt)

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ChatWeb.ConnCase
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
