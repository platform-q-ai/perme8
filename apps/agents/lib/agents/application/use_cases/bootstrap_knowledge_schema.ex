defmodule Agents.Application.UseCases.BootstrapKnowledgeSchema do
  @moduledoc """
  Idempotent ERM schema setup per workspace.

  Ensures the workspace has a KnowledgeEntry entity type and all
  knowledge relationship edge types registered in the ERM schema.
  """

  @knowledge_entity_type "KnowledgeEntry"
  @edge_type_names ~w(relates_to depends_on prerequisite_for example_of part_of supersedes)

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def execute(workspace_id, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, GatewayConfig.erm_gateway())

    case erm_gateway.get_schema(workspace_id) do
      {:ok, schema} ->
        if has_knowledge_type?(schema) do
          {:ok, :already_bootstrapped}
        else
          upsert_with_knowledge(erm_gateway, workspace_id, schema)
        end

      {:error, :not_found} ->
        create_knowledge_schema(erm_gateway, workspace_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp has_knowledge_type?(schema) do
    Enum.any?(schema.entity_types, fn et -> et.name == @knowledge_entity_type end)
  end

  defp upsert_with_knowledge(erm_gateway, workspace_id, existing_schema) do
    existing_edge_names = MapSet.new(existing_schema.edge_types, & &1.name)

    new_edge_types =
      Enum.reject(knowledge_edge_types(), fn et -> et.name in existing_edge_names end)

    attrs = %{
      entity_types: existing_schema.entity_types ++ [knowledge_entity_type()],
      edge_types: existing_schema.edge_types ++ new_edge_types
    }

    erm_gateway.upsert_schema(workspace_id, attrs)
  end

  defp create_knowledge_schema(erm_gateway, workspace_id) do
    attrs = %{
      entity_types: [knowledge_entity_type()],
      edge_types: knowledge_edge_types()
    }

    erm_gateway.upsert_schema(workspace_id, attrs)
  end

  defp knowledge_entity_type do
    %{
      name: @knowledge_entity_type,
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
  end

  defp knowledge_edge_types do
    Enum.map(@edge_type_names, fn name ->
      %{name: name, properties: []}
    end)
  end
end
