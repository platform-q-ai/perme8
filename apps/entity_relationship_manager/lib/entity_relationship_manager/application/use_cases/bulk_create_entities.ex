defmodule EntityRelationshipManager.Application.UseCases.BulkCreateEntities do
  @moduledoc """
  Use case for bulk-creating entities in the graph.

  Fetches the schema, validates each entity, then creates them in bulk.
  Supports `:atomic` (all-or-nothing) and `:partial` (create valid, report errors) modes.
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
  Bulk-creates entities in the workspace graph.

  Options:
  - `mode` - `:atomic` (default) or `:partial`

  In atomic mode, returns `{:ok, [entity]}` or `{:error, {:validation_errors, errors}}`.
  In partial mode, returns `{:ok, %{created: [entity], errors: [error]}}`.
  """
  def execute(workspace_id, entities_attrs, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, @schema_repo)
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)
    mode = Keyword.get(opts, :mode, :atomic)

    with :ok <- validate_batch_size(entities_attrs),
         {:ok, schema} <- fetch_schema(schema_repo, workspace_id) do
      {valid, errors} = validate_entities(schema, entities_attrs)

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

  defp validate_entities(schema, entities_attrs) do
    entities_attrs
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {attrs, index}, {valid_acc, error_acc} ->
      type = Map.get(attrs, :type)
      properties = Map.get(attrs, :properties, %{})

      case validate_single_entity(schema, type, properties) do
        :ok ->
          {[attrs | valid_acc], error_acc}

        {:error, reason} ->
          {valid_acc, [%{index: index, attrs: attrs, reason: reason} | error_acc]}
      end
    end)
    |> then(fn {valid, errors} -> {Enum.reverse(valid), Enum.reverse(errors)} end)
  end

  defp validate_single_entity(schema, type, properties) do
    with :ok <- InputSanitizationPolicy.validate_type_name(type) do
      entity = Entity.new(%{type: type, properties: properties})

      case SchemaValidationPolicy.validate_entity_against_schema(entity, schema, type) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp handle_atomic(_graph_repo, _workspace_id, _valid, errors) when errors != [] do
    {:error, {:validation_errors, errors}}
  end

  defp handle_atomic(graph_repo, workspace_id, valid, _errors) do
    graph_repo.bulk_create_entities(workspace_id, valid)
  end

  defp handle_partial(_graph_repo, _workspace_id, [], errors) do
    {:ok, %{created: [], errors: errors}}
  end

  defp handle_partial(graph_repo, workspace_id, valid, errors) do
    case graph_repo.bulk_create_entities(workspace_id, valid) do
      {:ok, created} -> {:ok, %{created: created, errors: errors}}
      {:error, reason} -> {:error, reason}
    end
  end
end
