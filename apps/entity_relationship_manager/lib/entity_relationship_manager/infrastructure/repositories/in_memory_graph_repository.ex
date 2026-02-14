defmodule EntityRelationshipManager.Infrastructure.Repositories.InMemoryGraphRepository do
  @moduledoc """
  ETS-backed in-memory graph repository for integration/BDD testing.

  Provides a full implementation of `GraphRepositoryBehaviour` without
  requiring Neo4j. Data is stored in two ETS tables (entities and edges)
  scoped by workspace_id.

  Call `reset!/0` to clear all data between test runs.
  """

  @behaviour EntityRelationshipManager.Application.Behaviours.GraphRepositoryBehaviour

  alias EntityRelationshipManager.Domain.Entities.Entity
  alias EntityRelationshipManager.Domain.Entities.Edge

  @entities_table :erm_inmemory_entities
  @edges_table :erm_inmemory_edges

  # ── Table lifecycle ────────────────────────────────────────────────

  @doc "Ensure ETS tables exist. Safe to call multiple times."
  def init! do
    unless :ets.whereis(@entities_table) != :undefined do
      :ets.new(@entities_table, [:set, :public, :named_table])
    end

    unless :ets.whereis(@edges_table) != :undefined do
      :ets.new(@edges_table, [:set, :public, :named_table])
    end

    :ok
  end

  @doc "Clear all data from both tables."
  def reset! do
    init!()
    :ets.delete_all_objects(@entities_table)
    :ets.delete_all_objects(@edges_table)
    :ok
  end

  # ── Entity CRUD ────────────────────────────────────────────────────

  @impl true
  def create_entity(workspace_id, type, properties, _opts \\ []) do
    init!()
    now = DateTime.utc_now()
    id = Ecto.UUID.generate()

    entity =
      Entity.new(%{
        id: id,
        workspace_id: workspace_id,
        type: type,
        properties: properties,
        created_at: now,
        updated_at: now,
        deleted_at: nil
      })

    :ets.insert(@entities_table, {{workspace_id, id}, entity})
    {:ok, entity}
  end

  @impl true
  def get_entity(workspace_id, entity_id, opts \\ []) do
    init!()
    include_deleted = Keyword.get(opts, :include_deleted, false)

    case :ets.lookup(@entities_table, {workspace_id, entity_id}) do
      [{_key, %Entity{deleted_at: nil} = entity}] -> {:ok, entity}
      [{_key, %Entity{} = entity}] when include_deleted -> {:ok, entity}
      [{_key, %Entity{}}] -> {:error, :not_found}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def list_entities(workspace_id, filters, _opts \\ []) do
    init!()
    type_filter = Map.get(filters, :type)
    include_deleted = Map.get(filters, :include_deleted, false)

    entities =
      all_entities(workspace_id)
      |> maybe_filter_deleted(include_deleted)
      |> maybe_filter_type(type_filter)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    {:ok, entities}
  end

  @impl true
  def update_entity(workspace_id, entity_id, properties, _opts \\ []) do
    init!()

    case :ets.lookup(@entities_table, {workspace_id, entity_id}) do
      [{key, %Entity{deleted_at: nil} = entity}] ->
        updated = %{entity | properties: properties, updated_at: DateTime.utc_now()}
        :ets.insert(@entities_table, {key, updated})
        {:ok, updated}

      [{_key, %Entity{}}] ->
        {:error, :not_found}

      [] ->
        {:error, :not_found}
    end
  end

  @impl true
  def soft_delete_entity(workspace_id, entity_id, _opts \\ []) do
    init!()
    now = DateTime.utc_now()

    case :ets.lookup(@entities_table, {workspace_id, entity_id}) do
      [{key, %Entity{deleted_at: nil} = entity}] ->
        deleted = %{entity | deleted_at: now, updated_at: now}
        :ets.insert(@entities_table, {key, deleted})

        # Cascade soft-delete to connected edges
        deleted_edge_count = cascade_delete_edges(workspace_id, entity_id, now)

        {:ok, deleted, deleted_edge_count}

      [{_key, %Entity{}}] ->
        {:error, :not_found}

      [] ->
        {:error, :not_found}
    end
  end

  # ── Edge CRUD ──────────────────────────────────────────────────────

  @impl true
  def create_edge(workspace_id, type, source_id, target_id, properties, _opts \\ []) do
    init!()

    # Verify both endpoints exist (specific error per endpoint)
    case get_entity(workspace_id, source_id) do
      {:error, :not_found} ->
        {:error, :source_not_found}

      {:ok, _} ->
        case get_entity(workspace_id, target_id) do
          {:error, :not_found} ->
            {:error, :target_not_found}

          {:ok, _} ->
            now = DateTime.utc_now()
            id = Ecto.UUID.generate()

            edge =
              Edge.new(%{
                id: id,
                workspace_id: workspace_id,
                type: type,
                source_id: source_id,
                target_id: target_id,
                properties: properties,
                created_at: now,
                updated_at: now,
                deleted_at: nil
              })

            :ets.insert(@edges_table, {{workspace_id, id}, edge})
            {:ok, edge}
        end
    end
  end

  @impl true
  def get_edge(workspace_id, edge_id, _opts \\ []) do
    init!()

    case :ets.lookup(@edges_table, {workspace_id, edge_id}) do
      [{_key, %Edge{deleted_at: nil} = edge}] -> {:ok, edge}
      [{_key, %Edge{}}] -> {:error, :not_found}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def list_edges(workspace_id, filters, _opts \\ []) do
    init!()
    type_filter = Map.get(filters, :type)
    include_deleted = Map.get(filters, :include_deleted, false)

    edges =
      all_edges(workspace_id)
      |> maybe_filter_deleted_edges(include_deleted)
      |> maybe_filter_edge_type(type_filter)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    {:ok, edges}
  end

  @impl true
  def update_edge(workspace_id, edge_id, properties, _opts \\ []) do
    init!()

    case :ets.lookup(@edges_table, {workspace_id, edge_id}) do
      [{key, %Edge{deleted_at: nil} = edge}] ->
        updated = %{edge | properties: properties, updated_at: DateTime.utc_now()}
        :ets.insert(@edges_table, {key, updated})
        {:ok, updated}

      [{_key, %Edge{}}] ->
        {:error, :not_found}

      [] ->
        {:error, :not_found}
    end
  end

  @impl true
  def soft_delete_edge(workspace_id, edge_id, _opts \\ []) do
    init!()
    now = DateTime.utc_now()

    case :ets.lookup(@edges_table, {workspace_id, edge_id}) do
      [{key, %Edge{deleted_at: nil} = edge}] ->
        deleted = %{edge | deleted_at: now, updated_at: now}
        :ets.insert(@edges_table, {key, deleted})
        {:ok, deleted}

      [{_key, %Edge{}}] ->
        {:error, :not_found}

      [] ->
        {:error, :not_found}
    end
  end

  # ── Traversal ──────────────────────────────────────────────────────

  @impl true
  def get_neighbors(workspace_id, entity_id, opts \\ []) do
    init!()
    direction = Keyword.get(opts, :direction, "both")
    edge_type = Keyword.get(opts, :edge_type)

    # Verify entity exists
    case get_entity(workspace_id, entity_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, _} ->
        edges =
          all_edges(workspace_id)
          |> Enum.filter(&is_nil(&1.deleted_at))
          |> maybe_filter_edge_type(edge_type)

        neighbor_ids =
          edges
          |> Enum.flat_map(fn edge ->
            case direction do
              "out" ->
                if edge.source_id == entity_id, do: [edge.target_id], else: []

              "in" ->
                if edge.target_id == entity_id, do: [edge.source_id], else: []

              _ ->
                cond do
                  edge.source_id == entity_id -> [edge.target_id]
                  edge.target_id == entity_id -> [edge.source_id]
                  true -> []
                end
            end
          end)
          |> Enum.uniq()

        neighbors =
          neighbor_ids
          |> Enum.flat_map(fn nid ->
            case get_entity(workspace_id, nid) do
              {:ok, entity} -> [entity]
              _ -> []
            end
          end)

        {:ok, neighbors}
    end
  end

  @impl true
  def find_paths(workspace_id, source_id, target_id, opts \\ []) do
    init!()
    max_depth = Keyword.get(opts, :max_depth, 5)

    # Verify both entities exist
    with {:ok, _} <- get_entity(workspace_id, source_id),
         {:ok, _} <- get_entity(workspace_id, target_id) do
      edges =
        all_edges(workspace_id)
        |> Enum.filter(&is_nil(&1.deleted_at))

      paths = bfs_paths(source_id, target_id, edges, max_depth)
      {:ok, paths}
    else
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @impl true
  def traverse(workspace_id, start_id, opts \\ []) do
    init!()
    max_depth = Keyword.get(opts, :max_depth, 3)

    case get_entity(workspace_id, start_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, start_entity} ->
        edges =
          all_edges(workspace_id)
          |> Enum.filter(&is_nil(&1.deleted_at))

        visited = bfs_traverse(start_id, edges, max_depth)

        entities =
          visited
          |> Enum.flat_map(fn nid ->
            case get_entity(workspace_id, nid) do
              {:ok, entity} -> [entity]
              _ -> []
            end
          end)

        # Include the start entity if not already present
        entity_ids = MapSet.new(Enum.map(entities, & &1.id))

        entities =
          if MapSet.member?(entity_ids, start_entity.id) do
            entities
          else
            [start_entity | entities]
          end

        {:ok, entities}
    end
  end

  # ── Bulk operations ────────────────────────────────────────────────

  @impl true
  def bulk_create_entities(workspace_id, entities_attrs, _opts \\ []) do
    init!()
    now = DateTime.utc_now()

    entities =
      Enum.map(entities_attrs, fn attrs ->
        id = Ecto.UUID.generate()

        entity =
          Entity.new(%{
            id: id,
            workspace_id: workspace_id,
            type: Map.get(attrs, :type),
            properties: Map.get(attrs, :properties, %{}),
            created_at: now,
            updated_at: now,
            deleted_at: nil
          })

        :ets.insert(@entities_table, {{workspace_id, id}, entity})
        entity
      end)

    {:ok, entities}
  end

  @impl true
  def bulk_create_edges(workspace_id, edges_attrs, _opts \\ []) do
    init!()
    now = DateTime.utc_now()

    {created, errors} =
      edges_attrs
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {attrs, index}, {created_acc, error_acc} ->
        source_id = Map.get(attrs, :source_id)
        target_id = Map.get(attrs, :target_id)

        source_exists = entity_exists?(workspace_id, source_id)
        target_exists = entity_exists?(workspace_id, target_id)

        cond do
          not source_exists ->
            {created_acc, [%{index: index, reason: :source_not_found} | error_acc]}

          not target_exists ->
            {created_acc, [%{index: index, reason: :target_not_found} | error_acc]}

          true ->
            id = Ecto.UUID.generate()

            edge =
              Edge.new(%{
                id: id,
                workspace_id: workspace_id,
                type: Map.get(attrs, :type),
                source_id: source_id,
                target_id: target_id,
                properties: Map.get(attrs, :properties, %{}),
                created_at: now,
                updated_at: now,
                deleted_at: nil
              })

            :ets.insert(@edges_table, {{workspace_id, id}, edge})
            {[edge | created_acc], error_acc}
        end
      end)

    if errors == [] do
      {:ok, Enum.reverse(created)}
    else
      {:ok, %{created: Enum.reverse(created), errors: Enum.reverse(errors)}}
    end
  end

  defp entity_exists?(workspace_id, entity_id) do
    case :ets.lookup(@entities_table, {workspace_id, entity_id}) do
      [{_key, %Entity{deleted_at: nil}}] -> true
      _ -> false
    end
  end

  @impl true
  def bulk_update_entities(workspace_id, updates, _opts \\ []) do
    init!()
    now = DateTime.utc_now()

    results =
      Enum.flat_map(updates, fn update ->
        entity_id = Map.get(update, :id)
        properties = Map.get(update, :properties, %{})

        case :ets.lookup(@entities_table, {workspace_id, entity_id}) do
          [{key, %Entity{deleted_at: nil} = entity}] ->
            updated = %{entity | properties: properties, updated_at: now}
            :ets.insert(@entities_table, {key, updated})
            [updated]

          _ ->
            []
        end
      end)

    {:ok, results}
  end

  @impl true
  def bulk_soft_delete_entities(workspace_id, entity_ids, _opts \\ []) do
    init!()
    now = DateTime.utc_now()

    count =
      Enum.count(entity_ids, fn entity_id ->
        case :ets.lookup(@entities_table, {workspace_id, entity_id}) do
          [{key, %Entity{deleted_at: nil} = entity}] ->
            deleted = %{entity | deleted_at: now, updated_at: now}
            :ets.insert(@entities_table, {key, deleted})
            cascade_delete_edges(workspace_id, entity_id, now)
            true

          _ ->
            false
        end
      end)

    {:ok, count}
  end

  @impl true
  def batch_get_entities(workspace_id, entity_ids, _opts \\ []) do
    init!()

    entities_map =
      entity_ids
      |> Enum.flat_map(fn id ->
        case get_entity(workspace_id, id) do
          {:ok, entity} -> [{id, entity}]
          _ -> []
        end
      end)
      |> Map.new()

    {:ok, entities_map}
  end

  # ── Health ─────────────────────────────────────────────────────────

  @impl true
  def health_check(_opts \\ []) do
    init!()
    :ok
  end

  # ── Private helpers ────────────────────────────────────────────────

  defp all_entities(workspace_id) do
    :ets.tab2list(@entities_table)
    |> Enum.filter(fn {{ws_id, _}, _} -> ws_id == workspace_id end)
    |> Enum.map(fn {_, entity} -> entity end)
  end

  defp all_edges(workspace_id) do
    :ets.tab2list(@edges_table)
    |> Enum.filter(fn {{ws_id, _}, _} -> ws_id == workspace_id end)
    |> Enum.map(fn {_, edge} -> edge end)
  end

  defp maybe_filter_deleted(entities, true), do: entities
  defp maybe_filter_deleted(entities, _), do: Enum.filter(entities, &is_nil(&1.deleted_at))

  defp maybe_filter_deleted_edges(edges, true), do: edges
  defp maybe_filter_deleted_edges(edges, _), do: Enum.filter(edges, &is_nil(&1.deleted_at))

  defp maybe_filter_type(entities, nil), do: entities
  defp maybe_filter_type(entities, type), do: Enum.filter(entities, &(&1.type == type))

  defp maybe_filter_edge_type(edges, nil), do: edges
  defp maybe_filter_edge_type(edges, type), do: Enum.filter(edges, &(&1.type == type))

  defp cascade_delete_edges(workspace_id, entity_id, now) do
    all_edges(workspace_id)
    |> Enum.filter(fn edge ->
      is_nil(edge.deleted_at) &&
        (edge.source_id == entity_id || edge.target_id == entity_id)
    end)
    |> Enum.each(fn edge ->
      deleted = %{edge | deleted_at: now, updated_at: now}
      :ets.insert(@edges_table, {{workspace_id, edge.id}, deleted})
    end)
    |> then(fn _ ->
      all_edges(workspace_id)
      |> Enum.count(fn edge ->
        edge.deleted_at == now &&
          (edge.source_id == entity_id || edge.target_id == entity_id)
      end)
    end)
  end

  # BFS for path finding
  defp bfs_paths(source_id, target_id, edges, max_depth) do
    queue = :queue.from_list([{source_id, [source_id]}])
    do_bfs_paths(queue, target_id, edges, max_depth, MapSet.new(), [])
  end

  defp do_bfs_paths(queue, target_id, edges, max_depth, _visited, found_paths) do
    case :queue.out(queue) do
      {:empty, _} ->
        found_paths

      {{:value, {current_id, path}}, rest_queue} ->
        if current_id == target_id and length(path) > 1 do
          # Found a path — collect it and continue
          path_data = %{
            "nodes" => path,
            "edges" => path_edges(path, edges)
          }

          do_bfs_paths(rest_queue, target_id, edges, max_depth, MapSet.new(), [
            path_data | found_paths
          ])
        else
          if length(path) - 1 >= max_depth do
            do_bfs_paths(rest_queue, target_id, edges, max_depth, MapSet.new(), found_paths)
          else
            neighbors =
              edges
              |> Enum.flat_map(fn edge ->
                cond do
                  edge.source_id == current_id and edge.target_id not in path ->
                    [{edge.target_id, path ++ [edge.target_id]}]

                  edge.target_id == current_id and edge.source_id not in path ->
                    [{edge.source_id, path ++ [edge.source_id]}]

                  true ->
                    []
                end
              end)

            new_queue =
              Enum.reduce(neighbors, rest_queue, fn item, q -> :queue.in(item, q) end)

            do_bfs_paths(new_queue, target_id, edges, max_depth, MapSet.new(), found_paths)
          end
        end
    end
  end

  defp path_edges(path, edges) do
    path
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [a, b] ->
      Enum.filter(edges, fn edge ->
        (edge.source_id == a and edge.target_id == b) or
          (edge.source_id == b and edge.target_id == a)
      end)
      |> Enum.map(& &1.id)
    end)
  end

  # BFS for traverse (returns set of visited node IDs)
  defp bfs_traverse(start_id, edges, max_depth) do
    do_bfs_traverse(
      :queue.from_list([{start_id, 0}]),
      edges,
      max_depth,
      MapSet.new([start_id])
    )
  end

  defp do_bfs_traverse(queue, edges, max_depth, visited) do
    case :queue.out(queue) do
      {:empty, _} ->
        MapSet.to_list(visited)

      {{:value, {current_id, depth}}, rest_queue} ->
        if depth >= max_depth do
          do_bfs_traverse(rest_queue, edges, max_depth, visited)
        else
          neighbor_ids =
            edges
            |> Enum.flat_map(fn edge ->
              cond do
                edge.source_id == current_id -> [edge.target_id]
                edge.target_id == current_id -> [edge.source_id]
                true -> []
              end
            end)
            |> Enum.reject(&MapSet.member?(visited, &1))

          new_visited = Enum.reduce(neighbor_ids, visited, &MapSet.put(&2, &1))

          new_queue =
            Enum.reduce(neighbor_ids, rest_queue, fn nid, q ->
              :queue.in({nid, depth + 1}, q)
            end)

          do_bfs_traverse(new_queue, edges, max_depth, new_visited)
        end
    end
  end
end
