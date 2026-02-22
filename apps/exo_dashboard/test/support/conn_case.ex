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

  @doc """
  Returns a conn with valid Basic Auth credentials set.
  """
  def authed_conn(conn) do
    credentials = Base.encode64("admin:secret")
    Plug.Conn.put_req_header(conn, "authorization", "Basic #{credentials}")
  end

  setup _tags do
    # Set default credentials so all tests pass through basic auth.
    # Individual auth tests may override these.
    Application.put_env(:jarga, :dashboard_username, "admin")
    Application.put_env(:jarga, :dashboard_password, "secret")

    on_exit(fn ->
      Application.delete_env(:jarga, :dashboard_username)
      Application.delete_env(:jarga, :dashboard_password)
    end)

    conn =
      Phoenix.ConnTest.build_conn()
      |> authed_conn()

    {:ok, conn: conn}
  end
end
