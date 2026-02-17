defmodule Agents.Infrastructure.Mcp.Tools.GetToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.GetTool
  alias Agents.Test.KnowledgeFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :erm_gateway, Agents.Mocks.ErmGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :erm_gateway) end)
    :ok
  end

  defp build_frame(workspace_id) do
    Frame.new(%{workspace_id: workspace_id})
  end

  describe "execute/2" do
    test "returns full entry with relationships" do
      workspace_id = Fixtures.workspace_id()
      entity_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      entity = Fixtures.erm_knowledge_entity(%{id: entity_id, workspace_id: workspace_id})
      edge = Fixtures.erm_knowledge_edge(%{source_id: entity_id, workspace_id: workspace_id})

      Agents.Mocks.ErmGatewayMock
      |> expect(:get_entity, fn ^workspace_id, ^entity_id -> {:ok, entity} end)
      |> expect(:list_edges, fn ^workspace_id, %{entity_id: ^entity_id} -> {:ok, [edge]} end)

      params = %{id: entity_id}

      assert {:reply, response, ^frame} = GetTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Test Entry"
      assert text =~ "relates_to"
    end

    test "handles not_found error" do
      workspace_id = Fixtures.workspace_id()
      entity_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      Agents.Mocks.ErmGatewayMock
      |> expect(:get_entity, fn ^workspace_id, ^entity_id -> {:error, :not_found} end)

      params = %{id: entity_id}

      assert {:reply, response, ^frame} = GetTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "not found"
    end
  end
end
