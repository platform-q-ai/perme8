defmodule Agents.Domain.Entities.KnowledgeRelationshipTest do
  use ExUnit.Case, async: true

  alias Agents.Domain.Entities.KnowledgeRelationship

  import Agents.Test.KnowledgeFixtures

  describe "new/1" do
    test "creates a struct from valid attrs" do
      attrs = %{
        id: "rel-1",
        from_id: "entry-1",
        to_id: "entry-2",
        type: "relates_to",
        created_at: ~U[2026-01-01 00:00:00Z]
      }

      rel = KnowledgeRelationship.new(attrs)

      assert rel.id == "rel-1"
      assert rel.from_id == "entry-1"
      assert rel.to_id == "entry-2"
      assert rel.type == "relates_to"
      assert rel.created_at == ~U[2026-01-01 00:00:00Z]
    end
  end

  describe "from_erm_edge/1" do
    test "converts an ERM Edge into a KnowledgeRelationship" do
      source_id = unique_id()
      target_id = unique_id()

      edge =
        erm_knowledge_edge(%{
          id: "edge-123",
          type: "depends_on",
          source_id: source_id,
          target_id: target_id,
          created_at: ~U[2026-02-01 12:00:00Z]
        })

      rel = KnowledgeRelationship.from_erm_edge(edge)

      assert rel.id == "edge-123"
      assert rel.from_id == source_id
      assert rel.to_id == target_id
      assert rel.type == "depends_on"
      assert rel.created_at == ~U[2026-02-01 12:00:00Z]
    end
  end

  describe "all 6 relationship types are representable" do
    for type <- ~w(relates_to depends_on prerequisite_for example_of part_of supersedes) do
      test "#{type} is representable" do
        rel = KnowledgeRelationship.new(%{type: unquote(type)})
        assert rel.type == unquote(type)
      end
    end
  end
end
