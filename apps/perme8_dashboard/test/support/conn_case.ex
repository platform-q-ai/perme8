defmodule Perme8DashboardWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  No database is used -- Perme8Dashboard is a dev tool
  that wraps other dashboard apps.
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

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
