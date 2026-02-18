defmodule Agents.Infrastructure.Mcp.Tools.Jarga.GetWorkspaceToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Jarga.GetWorkspaceTool
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
    test "returns workspace details" do
      user_id = Fixtures.user_id()
      frame = build_frame(Fixtures.workspace_id(), user_id)

      workspace = Fixtures.workspace_map(%{name: "My Workspace", slug: "my-workspace"})

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_workspace, fn ^user_id, "my-workspace" -> {:ok, workspace} end)

      params = %{slug: "my-workspace"}

      assert {:reply, response, ^frame} = GetWorkspaceTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "My Workspace"
      assert text =~ "my-workspace"
    end

    test "handles not_found error" do
      user_id = Fixtures.user_id()
      frame = build_frame(Fixtures.workspace_id(), user_id)

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_workspace, fn ^user_id, "nonexistent" -> {:error, :not_found} end)

      params = %{slug: "nonexistent"}

      assert {:reply, response, ^frame} = GetWorkspaceTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "not found"
    end
  end
end
