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
    updates
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {update, index}, {valid_acc, error_acc} ->
      id = Map.get(update, :id)
      properties = Map.get(update, :properties, %{})

      case validate_single_update(graph_repo, workspace_id, schema, id, properties) do
        :ok ->
          {[update | valid_acc], error_acc}

        {:error, reason} ->
          {valid_acc, [%{index: index, id: id, reason: reason} | error_acc]}
      end
    end)
    |> then(fn {valid, errors} -> {Enum.reverse(valid), Enum.reverse(errors)} end)
  end

  defp validate_single_update(graph_repo, workspace_id, schema, id, properties) do
    with :ok <- InputSanitizationPolicy.validate_uuid(id),
         {:ok, existing} <- fetch_entity(graph_repo, workspace_id, id) do
      entity = Entity.new(%{type: existing.type, properties: properties})

      case SchemaValidationPolicy.validate_entity_against_schema(entity, schema, existing.type) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp fetch_entity(graph_repo, workspace_id, id) do
    case graph_repo.get_entity(workspace_id, id) do
      {:ok, entity} -> {:ok, entity}
      {:error, :not_found} -> {:error, :not_found}
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
