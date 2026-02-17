defmodule KnowledgeMcp.Application.UseCases.UpdateKnowledgeEntry do
  @moduledoc """
  Updates an existing knowledge entry's properties.

  Validates update attributes, fetches the existing entry, merges properties,
  and persists via ERM.
  """

  alias KnowledgeMcp.Domain.Entities.KnowledgeEntry
  alias KnowledgeMcp.Domain.Policies.KnowledgeValidationPolicy

  @updatable_fields ~w(title body category tags code_snippets file_paths external_links last_verified_at)a

  @doc """
  Updates a knowledge entry.

  ## Options

    * `:erm_gateway` - Module implementing ErmGatewayBehaviour
  """
  @spec execute(String.t(), String.t(), map(), keyword()) ::
          {:ok, KnowledgeEntry.t()} | {:error, atom()}
  def execute(workspace_id, entity_id, attrs, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, default_erm_gateway())

    with :ok <- KnowledgeValidationPolicy.validate_update_attrs(attrs),
         {:ok, existing} <- erm_gateway.get_entity(workspace_id, entity_id) do
      merged_properties = merge_properties(existing.properties, attrs)

      case erm_gateway.update_entity(workspace_id, entity_id, %{properties: merged_properties}) do
        {:ok, updated_entity} -> {:ok, KnowledgeEntry.from_erm_entity(updated_entity)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp merge_properties(existing_props, update_attrs) do
    # Build a temporary KnowledgeEntry from update attrs to get JSON-encoded properties
    update_entry = KnowledgeEntry.new(Map.take(update_attrs, @updatable_fields))
    update_props = KnowledgeEntry.to_erm_properties(update_entry)

    # Only merge fields that were actually provided in the update
    provided_keys =
      @updatable_fields
      |> Enum.filter(fn key -> Map.has_key?(update_attrs, key) end)
      |> Enum.map(&Atom.to_string/1)

    Enum.reduce(provided_keys, existing_props, fn key, acc ->
      Map.put(acc, key, Map.get(update_props, key))
    end)
  end

  defp default_erm_gateway do
    Application.get_env(:knowledge_mcp, :erm_gateway, KnowledgeMcp.Infrastructure.ErmGateway)
  end
end
