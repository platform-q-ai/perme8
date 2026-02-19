defmodule Agents.Application.UseCases.ListWorkspacesTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Application.UseCases.ListWorkspaces

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  describe "execute/2" do
    test "returns list of workspaces" do
      workspace = %{id: "ws-1", name: "My Workspace", slug: "my-workspace"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_workspaces, fn "user-1" -> {:ok, [workspace]} end)

      assert {:ok, [^workspace]} = ListWorkspaces.execute("user-1")
    end

    test "returns empty list when user has no workspaces" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_workspaces, fn "user-1" -> {:ok, []} end)

      assert {:ok, []} = ListWorkspaces.execute("user-1")
    end

    test "propagates gateway error" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_workspaces, fn "user-1" -> {:error, :user_not_found} end)

      assert {:error, :user_not_found} = ListWorkspaces.execute("user-1")
    end

    test "accepts jarga_gateway via opts for dependency injection" do
      workspace = %{id: "ws-2", name: "Injected Workspace", slug: "injected"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_workspaces, fn "user-2" -> {:ok, [workspace]} end)

      assert {:ok, [^workspace]} =
               ListWorkspaces.execute("user-2", jarga_gateway: Agents.Mocks.JargaGatewayMock)
    end
  end
end
