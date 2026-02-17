defmodule KnowledgeMcpTest do
  use ExUnit.Case, async: true

  import Mox

  alias KnowledgeMcp.Mocks.{ErmGatewayMock, IdentityMock}

  import KnowledgeMcp.Test.Fixtures

  setup :verify_on_exit!

  describe "authenticate/2" do
    test "delegates to AuthenticateRequest use case" do
      api_key = api_key_struct(%{workspace_access: [workspace_id()]})

      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:ok, api_key} end)

      assert {:ok, %{workspace_id: _, user_id: _}} =
               KnowledgeMcp.authenticate("token", identity_module: IdentityMock)
    end
  end

  describe "create/3" do
    test "delegates to CreateKnowledgeEntry use case" do
      # Bootstrap
      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition_with_knowledge()} end)
      |> expect(:create_entity, fn _ws_id, _attrs -> {:ok, erm_knowledge_entity()} end)

      attrs = valid_entry_attrs()

      assert {:ok, _entry} =
               KnowledgeMcp.create(workspace_id(), attrs, erm_gateway: ErmGatewayMock)
    end
  end

  describe "update/4" do
    test "delegates to UpdateKnowledgeEntry use case" do
      entity_id = unique_id()
      entity = erm_knowledge_entity(%{id: entity_id})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, entity} end)
      |> expect(:update_entity, fn _ws_id, _eid, _attrs -> {:ok, entity} end)

      assert {:ok, _entry} =
               KnowledgeMcp.update(workspace_id(), entity_id, %{title: "Updated"},
                 erm_gateway: ErmGatewayMock
               )
    end
  end

  describe "get/3" do
    test "delegates to GetKnowledgeEntry use case" do
      entity_id = unique_id()

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, erm_knowledge_entity(%{id: entity_id})} end)
      |> expect(:list_edges, fn _ws_id, _filters -> {:ok, []} end)

      assert {:ok, %{entry: _, relationships: _}} =
               KnowledgeMcp.get(workspace_id(), entity_id, erm_gateway: ErmGatewayMock)
    end
  end

  describe "search/3" do
    test "delegates to SearchKnowledgeEntries use case" do
      ErmGatewayMock
      |> expect(:list_entities, fn _ws_id, _filters -> {:ok, []} end)

      assert {:ok, []} =
               KnowledgeMcp.search(workspace_id(), %{query: "test"}, erm_gateway: ErmGatewayMock)
    end
  end

  describe "traverse/3" do
    test "delegates to TraverseKnowledgeGraph use case" do
      start_id = unique_id()

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, erm_knowledge_entity(%{id: start_id})} end)
      |> expect(:traverse, fn _ws_id, _sid, _opts -> {:ok, []} end)

      assert {:ok, []} =
               KnowledgeMcp.traverse(workspace_id(), %{start_id: start_id},
                 erm_gateway: ErmGatewayMock
               )
    end
  end

  describe "relate/3" do
    test "delegates to CreateKnowledgeRelationship use case" do
      from_id = unique_id()
      to_id = unique_id()

      # Bootstrap + entity checks + edge creation
      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition_with_knowledge()} end)
      |> expect(:get_entity, 2, fn _ws_id, _eid -> {:ok, erm_knowledge_entity()} end)
      |> expect(:create_edge, fn _ws_id, _attrs ->
        {:ok, erm_knowledge_edge(%{source_id: from_id, target_id: to_id})}
      end)

      assert {:ok, _rel} =
               KnowledgeMcp.relate(
                 workspace_id(),
                 %{from_id: from_id, to_id: to_id, type: "relates_to"},
                 erm_gateway: ErmGatewayMock
               )
    end
  end
end
