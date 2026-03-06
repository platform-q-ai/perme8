defmodule Agents.Infrastructure.Mcp.Tools.CreateToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.CreateTool
  alias Agents.Test.KnowledgeFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :erm_gateway, Agents.Mocks.ErmGatewayMock)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)

    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    on_exit(fn -> Application.delete_env(:agents, :erm_gateway) end)
    on_exit(fn -> Application.delete_env(:agents, :identity_module) end)
    :ok
  end

  defp actor_id, do: "test-actor-id"

  defp build_frame(workspace_id, actor_id, api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: workspace_id, user_id: actor_id, api_key: api_key})
  end

  describe "execute/2" do
    test "creates entry and returns it" do
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, actor_id())

      entity = Fixtures.erm_knowledge_entity(%{workspace_id: workspace_id})

      Agents.Mocks.ErmGatewayMock
      |> expect(:get_schema, fn ^workspace_id ->
        {:ok, Fixtures.schema_definition_with_knowledge()}
      end)
      |> expect(:create_entity, fn ^workspace_id, attrs, _actor_id ->
        assert attrs.type == "KnowledgeEntry"
        {:ok, entity}
      end)

      params = %{
        title: "How to test",
        body: "Write tests first",
        category: "how_to",
        tags: ["testing"],
        code_snippets: nil,
        file_paths: nil,
        external_links: nil
      }

      assert {:reply, response, ^frame} = CreateTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Test Entry"
    end

    test "handles validation errors with descriptive messages" do
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, actor_id())

      params = %{title: "", body: "Some body", category: "how_to"}

      assert {:reply, response, ^frame} = CreateTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
    end

    test "passes workspace_id from frame assigns" do
      workspace_id = "ws-create-test"
      frame = build_frame(workspace_id, actor_id())

      entity = Fixtures.erm_knowledge_entity(%{workspace_id: workspace_id})

      Agents.Mocks.ErmGatewayMock
      |> expect(:get_schema, fn ^workspace_id ->
        {:ok, Fixtures.schema_definition_with_knowledge()}
      end)
      |> expect(:create_entity, fn ^workspace_id, _attrs, _actor_id -> {:ok, entity} end)

      params = %{title: "Test", body: "Body", category: "how_to"}

      assert {:reply, _response, ^frame} = CreateTool.execute(params, frame)
    end

    test "denies execution when API key lacks knowledge.create scope" do
      workspace_id = Fixtures.workspace_id()
      api_key = Fixtures.api_key_struct(%{permissions: ["mcp:knowledge.search"]})
      frame = build_frame(workspace_id, actor_id(), api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.create" -> false end)

      params = %{title: "Test", body: "Body", category: "how_to"}

      assert {:reply, response, ^frame} = CreateTool.execute(params, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text == "Insufficient permissions: mcp:knowledge.create required"
    end
  end
end
