defmodule AgentsApi.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection for the Agents JSON API.

  Uses AgentsApi.Endpoint instead of JargaWeb.Endpoint.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # The default endpoint for testing
      @endpoint AgentsApi.Endpoint

      use AgentsApi, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import AgentsApi.ConnCase
    end
  end

  setup tags do
    setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Sets up the sandbox for both Jarga.Repo and Identity.Repo.
  """
  def setup_sandbox(tags) do
    :ok = Sandbox.checkout(Jarga.Repo)
    :ok = Sandbox.checkout(Identity.Repo)

    Sandbox.allow(Jarga.Repo, self(), self())
    Sandbox.allow(Identity.Repo, self(), self())

    unless tags[:async] do
      Sandbox.mode(Jarga.Repo, {:shared, self()})
      Sandbox.mode(Identity.Repo, {:shared, self()})
    end

    on_exit(fn ->
      Sandbox.checkin(Jarga.Repo)
      Sandbox.checkin(Identity.Repo)
    end)
  end
end
