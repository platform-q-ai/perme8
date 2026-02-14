defmodule EntityRelationshipManager.Application.UseCases.BulkCreateEdges do
  @moduledoc """
  Use case for bulk-creating edges in the graph.

  Fetches the schema, validates each edge type and properties, then creates
  in bulk. Supports `:atomic` and `:partial` modes.
  Maximum batch size: 1000 items.
  """

  alias EntityRelationshipManager.Domain.Entities.Edge

  alias EntityRelationshipManager.Application.RepoConfig

  alias EntityRelationshipManager.Domain.Policies.{
    SchemaValidationPolicy,
    InputSanitizationPolicy
  }

  @max_batch_size 1000

  @doc """
  Bulk-creates edges in the workspace graph.

  Each edge map should contain:
  - `type` - edge type name
  - `source_id` - source entity UUID
  - `target_id` - target entity UUID
  - `properties` - property values map

  Options:
  - `mode` - `:atomic` (default) or `:partial`
  """
  def execute(workspace_id, edges_attrs, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, RepoConfig.schema_repo())
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())
    mode = Keyword.get(opts, :mode, :atomic)

    with :ok <- validate_batch_size(edges_attrs),
         {:ok, schema} <- fetch_schema(schema_repo, workspace_id) do
      {valid, errors} = validate_edges(schema, edges_attrs)

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

  defp validate_edges(schema, edges_attrs) do
    edges_attrs
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {attrs, index}, {valid_acc, error_acc} ->
      type = Map.get(attrs, :type)
      properties = Map.get(attrs, :properties, %{})

      case validate_single_edge(schema, type, properties) do
        :ok ->
          {[attrs | valid_acc], error_acc}

        {:error, reason} ->
          {valid_acc, [%{index: index, attrs: attrs, reason: reason} | error_acc]}
      end
    end)
    |> then(fn {valid, errors} -> {Enum.reverse(valid), Enum.reverse(errors)} end)
  end

  defp validate_single_edge(schema, type, properties) do
    with :ok <- InputSanitizationPolicy.validate_type_name(type) do
      edge = Edge.new(%{type: type, properties: properties})

      case SchemaValidationPolicy.validate_edge_against_schema(edge, schema, type) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp handle_atomic(_graph_repo, _workspace_id, _valid, errors) when errors != [] do
    {:error, {:validation_errors, errors}}
  end

  defp handle_atomic(graph_repo, workspace_id, valid, _errors) do
    case graph_repo.bulk_create_edges(workspace_id, valid) do
      # Repo returned a partial result with entity-existence errors — reject all in atomic mode
      {:ok, %{created: _created, errors: repo_errors}} when repo_errors != [] ->
        {:error, {:validation_errors, repo_errors}}

      {:ok, %{created: created, errors: _}} ->
        {:ok, created}

      {:ok, created} when is_list(created) ->
        {:ok, created}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_partial(_graph_repo, _workspace_id, [], errors) do
    {:ok, %{created: [], errors: errors}}
  end

  defp handle_partial(graph_repo, workspace_id, valid, errors) do
    case graph_repo.bulk_create_edges(workspace_id, valid) do
      # Repo returned partial result with entity-existence errors — merge with validation errors
      {:ok, %{created: created, errors: repo_errors}} ->
        {:ok, %{created: created, errors: errors ++ repo_errors}}

      {:ok, created} when is_list(created) ->
        {:ok, %{created: created, errors: errors}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
