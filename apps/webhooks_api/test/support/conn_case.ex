defmodule WebhooksApi.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection for the Webhooks JSON API.

  Uses WebhooksApi.Endpoint.
  """

  use Boundary,
    top_level?: true,
    deps: [
      WebhooksApi,
      Identity,
      Jarga.DataCase
    ],
    exports: []

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint WebhooksApi.Endpoint

      use WebhooksApi, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import WebhooksApi.ConnCase
    end
  end

  setup tags do
    Jarga.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
