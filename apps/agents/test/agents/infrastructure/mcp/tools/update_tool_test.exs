defmodule Agents.Infrastructure.Mcp.Tools.UpdateToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.UpdateTool
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
    test "updates entry and returns it" do
      workspace_id = Fixtures.workspace_id()
      entity_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      existing = Fixtures.erm_knowledge_entity(%{id: entity_id, workspace_id: workspace_id})
      updated = %{existing | properties: Map.put(existing.properties, "title", "Updated Title")}

      Agents.Mocks.ErmGatewayMock
      |> expect(:get_entity, fn ^workspace_id, ^entity_id -> {:ok, existing} end)
      |> expect(:update_entity, fn ^workspace_id, ^entity_id, _attrs -> {:ok, updated} end)

      params = %{id: entity_id, title: "Updated Title"}

      assert {:reply, response, ^frame} = UpdateTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Updated Title"
    end

    test "handles not_found gracefully" do
      workspace_id = Fixtures.workspace_id()
      entity_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      Agents.Mocks.ErmGatewayMock
      |> expect(:get_entity, fn ^workspace_id, ^entity_id -> {:error, :not_found} end)

      params = %{id: entity_id, title: "New Title"}

      assert {:reply, response, ^frame} = UpdateTool.execute(params, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
    end

    test "handles validation errors" do
      workspace_id = Fixtures.workspace_id()
      entity_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      params = %{id: entity_id, category: "invalid_category"}

      assert {:reply, response, ^frame} = UpdateTool.execute(params, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
    end
  end
end
