defmodule KnowledgeMcp.Application.UseCases.CreateKnowledgeRelationshipTest do
  use ExUnit.Case, async: true

  import Mox

  alias KnowledgeMcp.Application.UseCases.CreateKnowledgeRelationship
  alias KnowledgeMcp.Domain.Entities.KnowledgeRelationship
  alias KnowledgeMcp.Mocks.ErmGatewayMock

  import KnowledgeMcp.Test.Fixtures

  setup :verify_on_exit!

  defp setup_bootstrap_and_entities(from_id, to_id) do
    # Bootstrap always succeeds
    ErmGatewayMock
    |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition_with_knowledge()} end)
    |> expect(:get_entity, fn _ws_id, eid ->
      if eid in [from_id, to_id],
        do: {:ok, erm_knowledge_entity(%{id: eid})},
        else: {:error, :not_found}
    end)
    |> expect(:get_entity, fn _ws_id, eid ->
      if eid in [from_id, to_id],
        do: {:ok, erm_knowledge_entity(%{id: eid})},
        else: {:error, :not_found}
    end)
  end

  describe "execute/3" do
    test "creates relationship between two entries" do
      from_id = unique_id()
      to_id = unique_id()
      setup_bootstrap_and_entities(from_id, to_id)

      edge = erm_knowledge_edge(%{source_id: from_id, target_id: to_id, type: "relates_to"})

      ErmGatewayMock
      |> expect(:create_edge, fn _ws_id, attrs ->
        assert attrs.source_id == from_id
        assert attrs.target_id == to_id
        assert attrs.type == "relates_to"
        {:ok, edge}
      end)

      assert {:ok, %KnowledgeRelationship{from_id: ^from_id, to_id: ^to_id, type: "relates_to"}} =
               CreateKnowledgeRelationship.execute(
                 workspace_id(),
                 %{from_id: from_id, to_id: to_id, type: "relates_to"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "returns {:error, :self_reference} when from_id == to_id" do
      id = unique_id()

      assert {:error, :self_reference} =
               CreateKnowledgeRelationship.execute(
                 workspace_id(),
                 %{from_id: id, to_id: id, type: "relates_to"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "returns {:error, :invalid_relationship_type} for bad type" do
      assert {:error, :invalid_relationship_type} =
               CreateKnowledgeRelationship.execute(
                 workspace_id(),
                 %{from_id: unique_id(), to_id: unique_id(), type: "bad_type"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "returns {:error, :not_found} when source entry doesn't exist" do
      from_id = unique_id()
      to_id = unique_id()

      # Bootstrap succeeds
      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition_with_knowledge()} end)
      |> expect(:get_entity, fn _ws_id, _eid -> {:error, :not_found} end)

      assert {:error, :not_found} =
               CreateKnowledgeRelationship.execute(
                 workspace_id(),
                 %{from_id: from_id, to_id: to_id, type: "relates_to"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "returns {:error, :not_found} when target entry doesn't exist" do
      from_id = unique_id()
      to_id = unique_id()

      # Bootstrap succeeds, source exists, target doesn't
      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition_with_knowledge()} end)
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, erm_knowledge_entity(%{id: from_id})} end)
      |> expect(:get_entity, fn _ws_id, _eid -> {:error, :not_found} end)

      assert {:error, :not_found} =
               CreateKnowledgeRelationship.execute(
                 workspace_id(),
                 %{from_id: from_id, to_id: to_id, type: "relates_to"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "idempotent: handles duplicate edge gracefully" do
      from_id = unique_id()
      to_id = unique_id()
      setup_bootstrap_and_entities(from_id, to_id)

      edge = erm_knowledge_edge(%{source_id: from_id, target_id: to_id, type: "relates_to"})

      ErmGatewayMock
      |> expect(:create_edge, fn _ws_id, _attrs ->
        # ERM might return the existing edge or create a new one
        {:ok, edge}
      end)

      assert {:ok, %KnowledgeRelationship{}} =
               CreateKnowledgeRelationship.execute(
                 workspace_id(),
                 %{from_id: from_id, to_id: to_id, type: "relates_to"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "calls BootstrapKnowledgeSchema first" do
      from_id = unique_id()
      to_id = unique_id()

      # Verify get_schema is called (part of bootstrap)
      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition_with_knowledge()} end)
      |> expect(:get_entity, 2, fn _ws_id, _eid -> {:ok, erm_knowledge_entity()} end)
      |> expect(:create_edge, fn _ws_id, _attrs -> {:ok, erm_knowledge_edge()} end)

      assert {:ok, _} =
               CreateKnowledgeRelationship.execute(
                 workspace_id(),
                 %{from_id: from_id, to_id: to_id, type: "relates_to"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "creates ERM edge with correct source_id, target_id, type" do
      from_id = unique_id()
      to_id = unique_id()
      setup_bootstrap_and_entities(from_id, to_id)

      ErmGatewayMock
      |> expect(:create_edge, fn _ws_id, attrs ->
        assert attrs.source_id == from_id
        assert attrs.target_id == to_id
        assert attrs.type == "depends_on"
        {:ok, erm_knowledge_edge(%{source_id: from_id, target_id: to_id, type: "depends_on"})}
      end)

      assert {:ok, %KnowledgeRelationship{type: "depends_on"}} =
               CreateKnowledgeRelationship.execute(
                 workspace_id(),
                 %{from_id: from_id, to_id: to_id, type: "depends_on"},
                 erm_gateway: ErmGatewayMock
               )
    end
  end
end
