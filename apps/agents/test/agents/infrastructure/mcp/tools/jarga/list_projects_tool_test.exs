defmodule Agents.Infrastructure.Mcp.Tools.Jarga.ListProjectsToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Jarga.ListProjectsTool
  alias Agents.Test.JargaFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  defp build_frame(workspace_id, user_id) do
    Frame.new(%{workspace_id: workspace_id, user_id: user_id})
  end

  describe "execute/2" do
    test "returns formatted list of projects" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      project1 = Fixtures.project_map(%{name: "Project Alpha", slug: "project-alpha"})
      project2 = Fixtures.project_map(%{name: "Project Beta", slug: "project-beta"})

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_projects, fn ^user_id, ^workspace_id ->
        {:ok, [project1, project2]}
      end)

      assert {:reply, response, ^frame} = ListProjectsTool.execute(%{}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Project Alpha"
      assert text =~ "Project Beta"
    end

    test "returns message when no projects found" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_projects, fn ^user_id, ^workspace_id -> {:ok, []} end)

      assert {:reply, response, ^frame} = ListProjectsTool.execute(%{}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "No projects found"
    end
  end
end
