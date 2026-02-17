defmodule KnowledgeMcp.Test.Fixtures do
  @moduledoc """
  Shared test fixtures for KnowledgeMcp tests.

  Provides pre-built domain entities and ERM structs for testing.
  Uses plain maps to avoid boundary violations with ERM internal types.
  """

  @workspace_id "ws-test-knowledge-001"

  def workspace_id, do: @workspace_id

  def unique_id, do: Ecto.UUID.generate()

  @doc """
  Returns a plain map representing an ERM Entity for a knowledge entry.
  Use this in Mox expectations where the ERM gateway returns entity data.
  """
  def erm_knowledge_entity(overrides \\ %{}) do
    defaults = %{
      id: unique_id(),
      workspace_id: @workspace_id,
      type: "KnowledgeEntry",
      properties: %{
        "title" => "Test Entry",
        "body" => "Test body content for the knowledge entry",
        "category" => "how_to",
        "tags" => Jason.encode!(["elixir", "testing"]),
        "code_snippets" => Jason.encode!([]),
        "file_paths" => Jason.encode!([]),
        "external_links" => Jason.encode!([]),
        "last_verified_at" => nil
      },
      created_at: ~U[2026-01-15 10:00:00Z],
      updated_at: ~U[2026-01-15 10:00:00Z],
      deleted_at: nil
    }

    Map.merge(defaults, overrides)
  end

  @doc """
  Returns a plain map representing an ERM Edge for a knowledge relationship.
  """
  def erm_knowledge_edge(overrides \\ %{}) do
    defaults = %{
      id: unique_id(),
      workspace_id: @workspace_id,
      type: "relates_to",
      source_id: unique_id(),
      target_id: unique_id(),
      properties: %{},
      created_at: ~U[2026-01-15 10:00:00Z],
      updated_at: ~U[2026-01-15 10:00:00Z],
      deleted_at: nil
    }

    Map.merge(defaults, overrides)
  end

  def valid_entry_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        title: "How to add a new context",
        body: "## Steps\n\n1. Create the module...",
        category: "how_to",
        tags: ["architecture", "contexts"],
        code_snippets: [],
        file_paths: ["lib/my_app/my_context.ex"],
        external_links: []
      },
      overrides
    )
  end

  def api_key_struct(overrides \\ %{}) do
    defaults = %{
      id: unique_id(),
      name: "Test Key",
      user_id: unique_id(),
      workspace_access: [@workspace_id],
      is_active: true,
      hashed_token: "hashed_test_token"
    }

    Map.merge(defaults, overrides)
  end

  @doc """
  Returns a plain map representing a schema definition with knowledge types.
  Used in bootstrap tests to simulate ERM schema responses.
  """
  def schema_definition_with_knowledge(overrides \\ %{}) do
    knowledge_entity_type = %{
      name: "KnowledgeEntry",
      properties: [
        %{name: "title", type: :string, required: true},
        %{name: "body", type: :string, required: true},
        %{name: "category", type: :string, required: true},
        %{name: "tags", type: :string, required: false},
        %{name: "code_snippets", type: :string, required: false},
        %{name: "file_paths", type: :string, required: false},
        %{name: "external_links", type: :string, required: false},
        %{name: "last_verified_at", type: :string, required: false}
      ]
    }

    edge_types =
      Enum.map(
        ["relates_to", "depends_on", "prerequisite_for", "example_of", "part_of", "supersedes"],
        fn name -> %{name: name, properties: []} end
      )

    defaults = %{
      id: "schema-knowledge-001",
      workspace_id: @workspace_id,
      version: 1,
      entity_types: [knowledge_entity_type],
      edge_types: edge_types
    }

    Map.merge(defaults, overrides)
  end
end
