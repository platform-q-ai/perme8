defmodule EntityRelationshipManager.Application.UseCases.BulkUpdateEntities do
  @moduledoc """
  Use case for bulk-updating entities in the graph.

  Fetches the schema, retrieves each existing entity, validates properties,
  then updates in bulk. Supports `:atomic` and `:partial` modes.
  Maximum batch size: 1000 items.
  """

  alias EntityRelationshipManager.Domain.Entities.Entity

  alias EntityRelationshipManager.Domain.Policies.{
    SchemaValidationPolicy,
    InputSanitizationPolicy
  }

  @max_batch_size 1000

  @schema_repo Application.compile_env(
                 :entity_relationship_manager,
                 :schema_repository,
                 EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository
               )

  @graph_repo Application.compile_env(
                :entity_relationship_manager,
                :graph_repository,
                EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
              )

  @doc """
  Bulk-updates entities in the workspace graph.

  Each update map should contain:
  - `id` - entity UUID
  - `properties` - new property values

  Options:
  - `mode` - `:atomic` (default) or `:partial`
  """
  def execute(workspace_id, updates, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, @schema_repo)
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)
    mode = Keyword.get(opts, :mode, :atomic)

    with :ok <- validate_batch_size(updates),
         {:ok, schema} <- fetch_schema(schema_repo, workspace_id) do
      {valid, errors} = validate_updates(graph_repo, workspace_id, schema, updates)

      case mode do
        :atomic -> handle_atomic(graph_repo, workspace_id, valid, errors)
        :partial -> handle_partial(graph_repo, workspace_id, valid, errors)
      end
    end
  end

  defp validate_batch_size([]), do: {:error, :empty_batch}

  defp validate_batch_size(items) when length(items) > @max_batch_size,
    do: {:error, :batch_too_large}

  defp validate_batch_size(_), do: :ok

  defp fetch_schema(schema_repo, workspace_id) do
    case schema_repo.get_schema(workspace_id) do
      {:ok, schema} -> {:ok, schema}
      {:error, :not_found} -> {:error, :schema_not_found}
    end
  end

  defp validate_updates(graph_repo, workspace_id, schema, updates) do
    # Validate all UUIDs first
    {uuid_valid, uuid_errors} =
      updates
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {update, index}, {valid_acc, error_acc} ->
        id = Map.get(update, :id)

        case InputSanitizationPolicy.validate_uuid(id) do
          :ok -> {[{update, index} | valid_acc], error_acc}
          {:error, reason} -> {valid_acc, [%{index: index, id: id, reason: reason} | error_acc]}
        end
      end)

    uuid_valid = Enum.reverse(uuid_valid)

    # Batch-fetch all entities in a single query
    entity_ids = Enum.map(uuid_valid, fn {update, _index} -> Map.get(update, :id) end)

    case graph_repo.batch_get_entities(workspace_id, entity_ids) do
      {:ok, entities_map} ->
        {valid, property_errors} =
          uuid_valid
          |> Enum.reduce({[], []}, &reduce_update(&1, &2, entities_map, schema))

        {Enum.reverse(valid), Enum.reverse(uuid_errors ++ property_errors)}

      {:error, reason} ->
        {[], [%{index: 0, id: nil, reason: reason}]}
    end
  end

  defp reduce_update({update, index}, {valid_acc, error_acc}, entities_map, schema) do
    id = Map.get(update, :id)
    properties = Map.get(update, :properties, %{})

    case validate_single_update(entities_map, schema, id, properties) do
      :ok -> {[update | valid_acc], error_acc}
      {:error, reason} -> {valid_acc, [%{index: index, id: id, reason: reason} | error_acc]}
    end
  end

  defp validate_single_update(entities_map, schema, id, properties) do
    case Map.fetch(entities_map, id) do
      {:ok, existing} ->
        entity = Entity.new(%{type: existing.type, properties: properties})

        case SchemaValidationPolicy.validate_entity_against_schema(entity, schema, existing.type) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp handle_atomic(_graph_repo, _workspace_id, _valid, errors) when errors != [] do
    {:error, {:validation_errors, errors}}
  end

  defp handle_atomic(graph_repo, workspace_id, valid, _errors) do
    graph_repo.bulk_update_entities(workspace_id, valid)
  end

  defp handle_partial(_graph_repo, _workspace_id, [], errors) do
    {:ok, %{updated: [], errors: errors}}
  end

  defp handle_partial(graph_repo, workspace_id, valid, errors) do
    case graph_repo.bulk_update_entities(workspace_id, valid) do
      {:ok, updated} -> {:ok, %{updated: updated, errors: errors}}
      {:error, reason} -> {:error, reason}
    end
  end
end
