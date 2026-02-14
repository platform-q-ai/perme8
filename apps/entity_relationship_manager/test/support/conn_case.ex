defmodule EntityRelationshipManager.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection for the ERM API.
  """

  use Boundary,
    top_level?: true,
    deps: [
      EntityRelationshipManager,
      Identity,
      Jarga.Accounts,
      Jarga.DataCase,
      Jarga.AccountsFixtures
    ],
    exports: []

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint EntityRelationshipManager.Endpoint

      use EntityRelationshipManager, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import EntityRelationshipManager.ConnCase
      import Mox
    end
  end

  setup tags do
    Jarga.DataCase.setup_sandbox(tags)
    Mox.set_mox_from_context(tags)
    Mox.verify_on_exit!(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Builds a connection with authentication assigns set, bypassing the auth plug.

  The conn will have `:current_user`, `:api_key`, `:workspace_id`, and `:member`
  assigns pre-populated. Use the `role` option to control the member's role.

  Returns `{conn, workspace_id}` for convenience.
  """
  def authenticated_conn(conn, opts \\ []) do
    role = Keyword.get(opts, :role, :owner)
    workspace_id = Keyword.get(opts, :workspace_id, Ecto.UUID.generate())
    user_id = Ecto.UUID.generate()

    conn =
      conn
      |> Plug.Conn.assign(:current_user, %{id: user_id, email: "test@example.com"})
      |> Plug.Conn.assign(:api_key, %{id: Ecto.UUID.generate(), user_id: user_id})
      |> Plug.Conn.assign(:workspace_id, workspace_id)
      |> Plug.Conn.assign(:member, %{role: role, user_id: user_id, workspace_id: workspace_id})

    {conn, workspace_id}
  end
end
