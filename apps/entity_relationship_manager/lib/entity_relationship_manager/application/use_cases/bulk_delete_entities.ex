defmodule EntityRelationshipManager.Application.UseCases.BulkDeleteEntities do
  @moduledoc """
  Use case for bulk soft-deleting entities.

  Validates all UUIDs then delegates to the graph repository.
  Supports `:atomic` and `:partial` modes.
  Maximum batch size: 1000 items.
  """

  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  @max_batch_size 1000

  @graph_repo Application.compile_env(
                :entity_relationship_manager,
                :graph_repository,
                EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
              )

  @doc """
  Bulk soft-deletes entities by their IDs.

  Options:
  - `mode` - `:atomic` (default) or `:partial`

  In atomic mode, returns `{:ok, deleted_count}` or `{:error, {:validation_errors, errors}}`.
  In partial mode, returns `{:ok, %{deleted_count: integer, errors: [error]}}`.
  """
  def execute(workspace_id, entity_ids, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)
    mode = Keyword.get(opts, :mode, :atomic)

    with :ok <- validate_batch_size(entity_ids) do
      {valid, errors} = validate_ids(entity_ids)

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

  defp validate_ids(ids) do
    ids
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {id, index}, {valid_acc, error_acc} ->
      case InputSanitizationPolicy.validate_uuid(id) do
        :ok ->
          {[id | valid_acc], error_acc}

        {:error, reason} ->
          {valid_acc, [%{index: index, id: id, reason: reason} | error_acc]}
      end
    end)
    |> then(fn {valid, errors} -> {Enum.reverse(valid), Enum.reverse(errors)} end)
  end

  defp handle_atomic(_graph_repo, _workspace_id, _valid, errors) when errors != [] do
    {:error, {:validation_errors, errors}}
  end

  defp handle_atomic(graph_repo, workspace_id, valid, _errors) do
    graph_repo.bulk_soft_delete_entities(workspace_id, valid)
  end

  defp handle_partial(_graph_repo, _workspace_id, [], errors) do
    {:ok, %{deleted_count: 0, errors: errors}}
  end

  defp handle_partial(graph_repo, workspace_id, valid, errors) do
    case graph_repo.bulk_soft_delete_entities(workspace_id, valid) do
      {:ok, count} -> {:ok, %{deleted_count: count, errors: errors}}
      {:error, reason} -> {:error, reason}
    end
  end
end
