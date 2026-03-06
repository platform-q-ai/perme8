defmodule Agents.Infrastructure.Mcp.Tools.SearchToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.SearchTool
  alias Agents.Test.KnowledgeFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :erm_gateway, Agents.Mocks.ErmGatewayMock)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)

    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    on_exit(fn ->
      Application.delete_env(:agents, :erm_gateway)
      Application.delete_env(:agents, :identity_module)
    end)

    :ok
  end

  defp build_frame(workspace_id, api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: workspace_id, api_key: api_key})
  end

  describe "execute/2" do
    test "calls SearchKnowledgeEntries and returns formatted results" do
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id)

      entity = Fixtures.erm_knowledge_entity(%{workspace_id: workspace_id})

      Agents.Mocks.ErmGatewayMock
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

      Agents.Mocks.ErmGatewayMock
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

      Agents.Mocks.ErmGatewayMock
      |> expect(:list_entities, fn ^workspace_id, _ -> {:ok, []} end)

      params = %{category: "how_to"}

      assert {:reply, _response, ^frame} =
               SearchTool.execute(params, frame)
    end

    test "denies execution when API key lacks knowledge.search scope" do
      workspace_id = Fixtures.workspace_id()
      api_key = Fixtures.api_key_struct(%{permissions: ["agents:read"]})
      frame = build_frame(workspace_id, api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.search" -> false end)

      assert {:reply, response, ^frame} = SearchTool.execute(%{query: "Test"}, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text == "Insufficient permissions: mcp:knowledge.search required"
    end
  end
end
