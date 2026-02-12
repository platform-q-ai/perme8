defmodule JargaApi.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection for the JSON API.

  Uses JargaApi.Endpoint instead of JargaWeb.Endpoint.
  """

  use Boundary,
    top_level?: true,
    deps: [
      JargaApi,
      Identity,
      Jarga.Accounts,
      Jarga.DataCase,
      Jarga.AccountsFixtures
    ],
    exports: []

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint JargaApi.Endpoint

      use JargaApi, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import JargaApi.ConnCase
    end
  end

  setup tags do
    Jarga.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
