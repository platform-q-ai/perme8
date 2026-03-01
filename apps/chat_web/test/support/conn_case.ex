defmodule ChatWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import ChatWeb.ConnCase
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Chat.Repo)
    :ok = Sandbox.checkout(Identity.Repo)

    Sandbox.allow(Chat.Repo, self(), self())
    Sandbox.allow(Identity.Repo, self(), self())

    unless tags[:async] do
      Sandbox.mode(Chat.Repo, {:shared, self()})
      Sandbox.mode(Identity.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
