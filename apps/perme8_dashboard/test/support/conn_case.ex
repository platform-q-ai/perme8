defmodule Perme8DashboardWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Includes database sandbox setup for tests that render LiveViews
  which access the database (e.g., chat sessions from Jarga.Chat).
  """
  use ExUnit.CaseTemplate

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
end
