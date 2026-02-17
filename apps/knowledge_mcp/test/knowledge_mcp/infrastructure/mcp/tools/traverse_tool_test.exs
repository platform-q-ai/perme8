defmodule KnowledgeMcp.Infrastructure.Mcp.Tools.TraverseToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias KnowledgeMcp.Infrastructure.Mcp.Tools.TraverseTool
  alias KnowledgeMcp.Test.Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:knowledge_mcp, :erm_gateway, KnowledgeMcp.Mocks.ErmGatewayMock)
    on_exit(fn -> Application.delete_env(:knowledge_mcp, :erm_gateway) end)
    :ok
  end

  defp build_frame(workspace_id) do
    Frame.new(%{workspace_id: workspace_id})
  end

  describe "execute/2" do
    test "returns traversal results" do
      workspace_id = Fixtures.workspace_id()
      start_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      neighbor = Fixtures.erm_knowledge_entity(%{workspace_id: workspace_id})

      KnowledgeMcp.Mocks.ErmGatewayMock
      |> expect(:get_entity, fn ^workspace_id, ^start_id ->
        {:ok, Fixtures.erm_knowledge_entity(%{id: start_id})}
      end)
      |> expect(:traverse, fn ^workspace_id, ^start_id, opts ->
        assert Keyword.get(opts, :depth) == 2
        {:ok, [neighbor]}
      end)

      params = %{id: start_id}

      assert {:reply, response, ^frame} = TraverseTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Test Entry"
    end

    test "handles optional relationship_type" do
      workspace_id = Fixtures.workspace_id()
      start_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      KnowledgeMcp.Mocks.ErmGatewayMock
      |> expect(:get_entity, fn ^workspace_id, ^start_id ->
        {:ok, Fixtures.erm_knowledge_entity(%{id: start_id})}
      end)
      |> expect(:traverse, fn ^workspace_id, ^start_id, opts ->
        assert Keyword.get(opts, :edge_type) == "depends_on"
        {:ok, []}
      end)

      params = %{id: start_id, relationship_type: "depends_on", depth: 3}

      assert {:reply, response, ^frame} = TraverseTool.execute(params, frame)
      assert %Hermes.Server.Response{type: :tool, isError: false} = response
    end

    test "handles not_found gracefully" do
      workspace_id = Fixtures.workspace_id()
      start_id = Fixtures.unique_id()
      frame = build_frame(workspace_id)

      KnowledgeMcp.Mocks.ErmGatewayMock
      |> expect(:get_entity, fn ^workspace_id, ^start_id -> {:error, :not_found} end)

      params = %{id: start_id}

      assert {:reply, response, ^frame} = TraverseTool.execute(params, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
    end
  end
end
