defmodule Agents.Application.UseCases.UpdateKnowledgeEntry do
  @moduledoc """
  Updates an existing knowledge entry's properties.

  Validates update attributes, fetches the existing entry, merges properties,
  and persists via ERM.
  """

  alias Agents.Application.GatewayConfig
  alias Agents.Domain.Entities.KnowledgeEntry
  alias Agents.Domain.Policies.KnowledgeValidationPolicy

  @updatable_fields ~w(title body category tags code_snippets file_paths external_links last_verified_at)a

  @spec execute(String.t(), String.t(), map(), keyword()) ::
          {:ok, KnowledgeEntry.t()} | {:error, atom()}
  def execute(workspace_id, entity_id, attrs, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, GatewayConfig.erm_gateway())

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
    update_entry = KnowledgeEntry.new(Map.take(update_attrs, @updatable_fields))
    update_props = KnowledgeEntry.to_erm_properties(update_entry)

    provided_keys =
      @updatable_fields
      |> Enum.filter(fn key -> Map.has_key?(update_attrs, key) end)
      |> Enum.map(&Atom.to_string/1)

    Enum.reduce(provided_keys, existing_props, fn key, acc ->
      Map.put(acc, key, Map.get(update_props, key))
    end)
  end
end
