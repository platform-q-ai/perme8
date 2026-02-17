defmodule KnowledgeMcp.Infrastructure.Mcp.Tools.SearchToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias KnowledgeMcp.Infrastructure.Mcp.Tools.SearchTool
  alias KnowledgeMcp.Test.Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    # Configure use cases to use mock gateway
    Application.put_env(:knowledge_mcp, :erm_gateway, KnowledgeMcp.Mocks.ErmGatewayMock)

    on_exit(fn ->
      Application.delete_env(:knowledge_mcp, :erm_gateway)
    end)

    :ok
  end

  defp build_frame(workspace_id) do
    Frame.new(%{workspace_id: workspace_id})
  end

  describe "execute/2" do
    test "calls SearchKnowledgeEntries and returns formatted results" do
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id)

      entity = Fixtures.erm_knowledge_entity(%{workspace_id: workspace_id})

      KnowledgeMcp.Mocks.ErmGatewayMock
      |> expect(:list_entities, fn ^workspace_id, %{type: "KnowledgeEntry"} ->
        {:ok, [entity]}
      end)

      params = %{query: "Test", tags: nil, category: nil, limit: nil}

      assert {:reply, response, ^frame} =
               SearchTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Test Entry"
    end

    test "handles empty results gracefully" do
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id)

      KnowledgeMcp.Mocks.ErmGatewayMock
      |> expect(:list_entities, fn ^workspace_id, %{type: "KnowledgeEntry"} ->
        {:ok, []}
      end)

      params = %{query: "nonexistent", tags: nil, category: nil, limit: nil}

      assert {:reply, response, ^frame} =
               SearchTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "No results"
    end

    test "handles empty_search error with user-friendly message" do
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id)

      params = %{}

      assert {:reply, response, ^frame} =
               SearchTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "search criteria"
    end

    test "passes workspace_id from frame assigns to use case" do
      workspace_id = "ws-custom-search"
      frame = build_frame(workspace_id)

      KnowledgeMcp.Mocks.ErmGatewayMock
      |> expect(:list_entities, fn ^workspace_id, _ -> {:ok, []} end)

      params = %{category: "how_to"}

      assert {:reply, _response, ^frame} =
               SearchTool.execute(params, frame)
    end
  end
end
