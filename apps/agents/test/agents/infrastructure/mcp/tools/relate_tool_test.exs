defmodule Agents.Infrastructure.Mcp.Tools.RelateToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.RelateTool
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
    test "creates relationship and returns it" do
      workspace_id = Fixtures.workspace_id()
      from_id = Fixtures.unique_id()
      to_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      edge =
        Fixtures.erm_knowledge_edge(%{
          source_id: from_id,
          target_id: to_id,
          type: "depends_on",
          workspace_id: workspace_id
        })

      Agents.Mocks.ErmGatewayMock
      |> expect(:get_schema, fn ^workspace_id ->
        {:ok, Fixtures.schema_definition_with_knowledge()}
      end)
      |> expect(:get_entity, fn ^workspace_id, ^from_id ->
        {:ok, Fixtures.erm_knowledge_entity(%{id: from_id})}
      end)
      |> expect(:get_entity, fn ^workspace_id, ^to_id ->
        {:ok, Fixtures.erm_knowledge_entity(%{id: to_id})}
      end)
      |> expect(:create_edge, fn ^workspace_id, attrs ->
        assert attrs.type == "depends_on"
        {:ok, edge}
      end)

      params = %{from_id: from_id, to_id: to_id, relationship_type: "depends_on"}

      assert {:reply, response, ^frame} = RelateTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "depends_on"
    end

    test "handles self-reference error" do
      workspace_id = Fixtures.workspace_id()
      entity_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      params = %{from_id: entity_id, to_id: entity_id, relationship_type: "relates_to"}

      assert {:reply, response, ^frame} = RelateTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "self"
    end

    test "handles invalid relationship type" do
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id)

      params = %{
        from_id: Fixtures.unique_id(),
        to_id: Fixtures.unique_id(),
        relationship_type: "invalid_type"
      }

      assert {:reply, response, ^frame} = RelateTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Valid types"
    end

    test "handles not_found gracefully" do
      workspace_id = Fixtures.workspace_id()
      from_id = Fixtures.unique_id()
      to_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      Agents.Mocks.ErmGatewayMock
      |> expect(:get_schema, fn ^workspace_id ->
        {:ok, Fixtures.schema_definition_with_knowledge()}
      end)
      |> expect(:get_entity, fn ^workspace_id, ^from_id -> {:error, :not_found} end)

      params = %{from_id: from_id, to_id: to_id, relationship_type: "relates_to"}

      assert {:reply, response, ^frame} = RelateTool.execute(params, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
    end
  end
end
