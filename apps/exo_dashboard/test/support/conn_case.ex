defmodule ExoDashboardWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  No database is used -- ExoDashboard is a dev tool
  that reads feature files from disk.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint ExoDashboardWeb.Endpoint

      use ExoDashboardWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import ExoDashboardWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
