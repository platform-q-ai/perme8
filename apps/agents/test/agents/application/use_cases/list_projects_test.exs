defmodule Agents.Application.UseCases.ListProjectsTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Application.UseCases.ListProjects

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  describe "execute/3" do
    test "returns list of projects for a workspace" do
      project = %{id: "proj-1", name: "My Project", slug: "my-project"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_projects, fn "user-1", "ws-1" -> {:ok, [project]} end)

      assert {:ok, [^project]} = ListProjects.execute("user-1", "ws-1")
    end

    test "returns empty list when workspace has no projects" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_projects, fn "user-1", "ws-1" -> {:ok, []} end)

      assert {:ok, []} = ListProjects.execute("user-1", "ws-1")
    end

    test "propagates gateway error" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_projects, fn "user-1", "ws-1" -> {:error, :workspace_not_found} end)

      assert {:error, :workspace_not_found} = ListProjects.execute("user-1", "ws-1")
    end

    test "accepts jarga_gateway via opts for dependency injection" do
      project = %{id: "proj-2", name: "Injected", slug: "injected"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_projects, fn "user-2", "ws-2" -> {:ok, [project]} end)

      assert {:ok, [^project]} =
               ListProjects.execute("user-2", "ws-2",
                 jarga_gateway: Agents.Mocks.JargaGatewayMock
               )
    end
  end
end
