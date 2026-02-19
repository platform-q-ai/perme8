defmodule Agents.Infrastructure.Mcp.Tools.Jarga.GetProjectToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Jarga.GetProjectTool
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
    test "returns project details" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      project =
        Fixtures.project_map(%{
          name: "My Project",
          slug: "my-project",
          description: "A great project"
        })

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn ^user_id, ^workspace_id, "my-project" ->
        {:ok, project}
      end)

      params = %{slug: "my-project"}

      assert {:reply, response, ^frame} = GetProjectTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "My Project"
      assert text =~ "my-project"
      assert text =~ "A great project"
    end

    test "handles project not found" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn ^user_id, ^workspace_id, "nonexistent" ->
        {:error, :project_not_found}
      end)

      params = %{slug: "nonexistent"}

      assert {:reply, response, ^frame} = GetProjectTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "not found"
    end
  end
end
