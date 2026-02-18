defmodule Agents.Application.UseCases.GetWorkspaceTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Application.UseCases.GetWorkspace

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  describe "execute/3" do
    test "returns workspace by slug" do
      workspace = %{id: "ws-1", name: "My Workspace", slug: "my-workspace"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_workspace, fn "user-1", "my-workspace" -> {:ok, workspace} end)

      assert {:ok, ^workspace} = GetWorkspace.execute("user-1", "my-workspace")
    end

    test "returns not_found when workspace does not exist" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_workspace, fn "user-1", "nonexistent" -> {:error, :not_found} end)

      assert {:error, :not_found} = GetWorkspace.execute("user-1", "nonexistent")
    end

    test "returns unauthorized when user lacks access" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_workspace, fn "user-1", "private-ws" -> {:error, :unauthorized} end)

      assert {:error, :unauthorized} = GetWorkspace.execute("user-1", "private-ws")
    end

    test "accepts jarga_gateway via opts for dependency injection" do
      workspace = %{id: "ws-2", name: "Injected", slug: "injected"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_workspace, fn "user-2", "injected" -> {:ok, workspace} end)

      assert {:ok, ^workspace} =
               GetWorkspace.execute("user-2", "injected",
                 jarga_gateway: Agents.Mocks.JargaGatewayMock
               )
    end
  end
end
