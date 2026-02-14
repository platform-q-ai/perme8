defmodule EntityRelationshipManager.Infrastructure.Repositories.GraphRepository do
  @moduledoc """
  Neo4j-backed graph repository implementing `GraphRepositoryBehaviour`.

  All Cypher queries use parameterized values (never string interpolation)
  and include `_workspace_id` for tenant isolation. Entities get an `:Entity`
  label plus a type-specific label. UUIDs are generated with `Ecto.UUID`.
  Timestamps are UTC DateTimes.

  Delegates query execution to `Neo4jAdapter`, which can be injected via
  opts for testing.
  """

  @behaviour EntityRelationshipManager.Application.Behaviours.GraphRepositoryBehaviour

  alias EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapter
  alias EntityRelationshipManager.Domain.Entities.Entity
  alias EntityRelationshipManager.Domain.Entities.Edge

  # ── Entity CRUD ──────────────────────────────────────────────────────

  @impl true
  def create_entity(workspace_id, type, properties, opts \\ []) do
    id = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    cypher = """
    CREATE (n:Entity {
      id: $id,
      _workspace_id: $_workspace_id,
      type: $type,
      properties: $properties,
      created_at: $now,
      updated_at: $now
    })
    RETURN n.id AS id, n.type AS type, n.properties AS properties,
           n.created_at AS created_at, n.updated_at AS updated_at
    """

    params = %{
      id: id,
      _workspace_id: workspace_id,
      type: type,
      properties: properties,
      now: now
    }

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        {:ok, record_to_entity(record, workspace_id)}

      {:ok, %{records: []}} ->
        {:error, :create_failed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def get_entity(workspace_id, entity_id, opts \\ []) do
    cypher = """
    MATCH (n:Entity {_workspace_id: $_workspace_id, id: $id})
    WHERE n.deleted_at IS NULL
    RETURN n.id AS id, n.type AS type, n.properties AS properties,
           n.created_at AS created_at, n.updated_at AS updated_at
    """

    params = %{_workspace_id: workspace_id, id: entity_id}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        {:ok, record_to_entity(record, workspace_id)}

      {:ok, %{records: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def list_entities(workspace_id, filters, opts \\ []) do
    {type_clause, type_params} = build_type_filter(filters)
    {limit, offset} = pagination_params(filters)

    cypher = """
    MATCH (n:Entity {_workspace_id: $_workspace_id})
    WHERE n.deleted_at IS NULL #{type_clause}
    RETURN n.id AS id, n.type AS type, n.properties AS properties,
           n.created_at AS created_at, n.updated_at AS updated_at
    ORDER BY n.created_at DESC
    SKIP $offset LIMIT $limit
    """

    params =
      %{_workspace_id: workspace_id, limit: limit, offset: offset}
      |> Map.merge(type_params)

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        {:ok, Enum.map(records, &record_to_entity(&1, workspace_id))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def update_entity(workspace_id, entity_id, properties, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    cypher = """
    MATCH (n:Entity {_workspace_id: $_workspace_id, id: $id})
    WHERE n.deleted_at IS NULL
    SET n.properties = $properties, n.updated_at = $now
    RETURN n.id AS id, n.type AS type, n.properties AS properties,
           n.created_at AS created_at, n.updated_at AS updated_at
    """

    params = %{
      _workspace_id: workspace_id,
      id: entity_id,
      properties: properties,
      now: now
    }

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        {:ok, record_to_entity(record, workspace_id)}

      {:ok, %{records: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def soft_delete_entity(workspace_id, entity_id, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    cypher = """
    MATCH (n:Entity {_workspace_id: $_workspace_id, id: $id})
    WHERE n.deleted_at IS NULL
    OPTIONAL MATCH (n)-[r]-()
    WHERE r.deleted_at IS NULL
    SET n.deleted_at = $now, n.updated_at = $now, r.deleted_at = $now
    WITH n, count(r) AS deleted_edge_count
    RETURN n.id AS id, n.type AS type, n.properties AS properties,
           n.created_at AS created_at, n.updated_at AS updated_at,
           n.deleted_at AS deleted_at, deleted_edge_count
    """

    params = %{_workspace_id: workspace_id, id: entity_id, now: now}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        entity = record_to_entity(record, workspace_id)
        deleted_edge_count = Map.get(record, "deleted_edge_count", 0)
        {:ok, entity, deleted_edge_count}

      {:ok, %{records: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Edge CRUD ──────────────────────────────────────────────────────

  @impl true
  def create_edge(workspace_id, type, source_id, target_id, properties, opts \\ []) do
    id = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    cypher = """
    MATCH (source:Entity {_workspace_id: $_workspace_id, id: $source_id})
    MATCH (target:Entity {_workspace_id: $_workspace_id, id: $target_id})
    CREATE (source)-[r:EDGE {
      id: $id,
      _workspace_id: $_workspace_id,
      type: $type,
      properties: $properties,
      created_at: $now,
      updated_at: $now
    }]->(target)
    RETURN r.id AS id, r.type AS type, r.properties AS properties,
           source.id AS source_id, target.id AS target_id,
           r.created_at AS created_at, r.updated_at AS updated_at
    """

    params = %{
      id: id,
      _workspace_id: workspace_id,
      type: type,
      source_id: source_id,
      target_id: target_id,
      properties: properties,
      now: now
    }

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        {:ok, record_to_edge(record, workspace_id)}

      {:ok, %{records: []}} ->
        {:error, :endpoints_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def get_edge(workspace_id, edge_id, opts \\ []) do
    cypher = """
    MATCH (source)-[r:EDGE {_workspace_id: $_workspace_id, id: $id}]->(target)
    WHERE r.deleted_at IS NULL
    RETURN r.id AS id, r.type AS type, r.properties AS properties,
           source.id AS source_id, target.id AS target_id,
           r.created_at AS created_at, r.updated_at AS updated_at
    """

    params = %{_workspace_id: workspace_id, id: edge_id}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        {:ok, record_to_edge(record, workspace_id)}

      {:ok, %{records: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def list_edges(workspace_id, filters, opts \\ []) do
    {type_clause, type_params} = build_edge_type_filter(filters)
    {limit, offset} = pagination_params(filters)

    cypher = """
    MATCH (source)-[r:EDGE {_workspace_id: $_workspace_id}]->(target)
    WHERE r.deleted_at IS NULL #{type_clause}
    RETURN r.id AS id, r.type AS type, r.properties AS properties,
           source.id AS source_id, target.id AS target_id,
           r.created_at AS created_at, r.updated_at AS updated_at
    ORDER BY r.created_at DESC
    SKIP $offset LIMIT $limit
    """

    params =
      %{_workspace_id: workspace_id, limit: limit, offset: offset}
      |> Map.merge(type_params)

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        {:ok, Enum.map(records, &record_to_edge(&1, workspace_id))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def update_edge(workspace_id, edge_id, properties, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    cypher = """
    MATCH (source)-[r:EDGE {_workspace_id: $_workspace_id, id: $id}]->(target)
    WHERE r.deleted_at IS NULL
    SET r.properties = $properties, r.updated_at = $now
    RETURN r.id AS id, r.type AS type, r.properties AS properties,
           source.id AS source_id, target.id AS target_id,
           r.created_at AS created_at, r.updated_at AS updated_at
    """

    params = %{
      _workspace_id: workspace_id,
      id: edge_id,
      properties: properties,
      now: now
    }

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        {:ok, record_to_edge(record, workspace_id)}

      {:ok, %{records: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def soft_delete_edge(workspace_id, edge_id, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    cypher = """
    MATCH (source)-[r:EDGE {_workspace_id: $_workspace_id, id: $id}]->(target)
    WHERE r.deleted_at IS NULL
    SET r.deleted_at = $now, r.updated_at = $now
    RETURN r.id AS id, r.type AS type, r.properties AS properties,
           source.id AS source_id, target.id AS target_id,
           r.created_at AS created_at, r.updated_at AS updated_at,
           r.deleted_at AS deleted_at
    """

    params = %{_workspace_id: workspace_id, id: edge_id, now: now}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        {:ok, record_to_edge(record, workspace_id)}

      {:ok, %{records: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Traversal ──────────────────────────────────────────────────────

  @impl true
  def get_neighbors(workspace_id, entity_id, opts \\ []) do
    direction = Keyword.get(opts, :direction, "both")
    edge_type = Keyword.get(opts, :edge_type)

    {match_pattern, edge_filter} = build_neighbor_pattern(direction, edge_type)

    cypher = """
    MATCH (start:Entity {_workspace_id: $_workspace_id, id: $id})
    #{match_pattern}
    WHERE neighbor.deleted_at IS NULL AND r.deleted_at IS NULL #{edge_filter}
    RETURN DISTINCT neighbor.id AS id, neighbor.type AS type,
           neighbor.properties AS properties,
           neighbor.created_at AS created_at, neighbor.updated_at AS updated_at
    """

    params =
      %{_workspace_id: workspace_id, id: entity_id}
      |> maybe_put_edge_type_param(edge_type)

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        {:ok, Enum.map(records, &record_to_entity(&1, workspace_id))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def find_paths(workspace_id, source_id, target_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 5)
    validate_max_depth!(max_depth)

    cypher = """
    MATCH (source:Entity {_workspace_id: $_workspace_id, id: $source_id}),
          (target:Entity {_workspace_id: $_workspace_id, id: $target_id}),
          p = allShortestPaths((source)-[*..#{max_depth}]-(target))
    WHERE ALL(n IN nodes(p) WHERE n.deleted_at IS NULL)
      AND ALL(r IN relationships(p) WHERE r.deleted_at IS NULL)
    RETURN [n IN nodes(p) | n.id] AS path
    """

    params = %{
      _workspace_id: workspace_id,
      source_id: source_id,
      target_id: target_id
    }

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        paths = Enum.map(records, &Map.get(&1, "path", []))
        {:ok, paths}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def traverse(workspace_id, start_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 3)
    validate_max_depth!(max_depth)
    limit = Keyword.get(opts, :limit, 1000)

    cypher = """
    MATCH (start:Entity {_workspace_id: $_workspace_id, id: $id})
    CALL {
      WITH start
      MATCH path = (start)-[*0..#{max_depth}]-(connected:Entity)
      WHERE connected.deleted_at IS NULL
        AND connected._workspace_id = $_workspace_id
        AND ALL(rel IN relationships(path) WHERE rel.deleted_at IS NULL)
      RETURN DISTINCT connected
    }
    RETURN connected.id AS id, connected.type AS type,
           connected.properties AS properties,
           connected.created_at AS created_at, connected.updated_at AS updated_at
    LIMIT $limit
    """

    params = %{_workspace_id: workspace_id, id: start_id, limit: limit}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        {:ok, Enum.map(records, &record_to_entity(&1, workspace_id))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Bulk operations ──────────────────────────────────────────────────

  @impl true
  def bulk_create_entities(workspace_id, entities, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    items =
      Enum.map(entities, fn entity ->
        %{
          id: Ecto.UUID.generate(),
          type: Map.get(entity, :type),
          properties: Map.get(entity, :properties, %{}),
          created_at: now,
          updated_at: now
        }
      end)

    cypher = """
    UNWIND $items AS item
    CREATE (n:Entity {
      id: item.id,
      _workspace_id: $_workspace_id,
      type: item.type,
      properties: item.properties,
      created_at: item.created_at,
      updated_at: item.updated_at
    })
    RETURN n.id AS id, n.type AS type, n.properties AS properties,
           n.created_at AS created_at, n.updated_at AS updated_at
    """

    params = %{_workspace_id: workspace_id, items: items}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        {:ok, Enum.map(records, &record_to_entity(&1, workspace_id))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def bulk_create_edges(workspace_id, edges, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    items =
      Enum.map(edges, fn edge ->
        %{
          id: Ecto.UUID.generate(),
          type: Map.get(edge, :type),
          source_id: Map.get(edge, :source_id),
          target_id: Map.get(edge, :target_id),
          properties: Map.get(edge, :properties, %{}),
          created_at: now,
          updated_at: now
        }
      end)

    cypher = """
    UNWIND $items AS item
    MATCH (source:Entity {_workspace_id: $_workspace_id, id: item.source_id})
    MATCH (target:Entity {_workspace_id: $_workspace_id, id: item.target_id})
    CREATE (source)-[r:EDGE {
      id: item.id,
      _workspace_id: $_workspace_id,
      type: item.type,
      properties: item.properties,
      created_at: item.created_at,
      updated_at: item.updated_at
    }]->(target)
    RETURN r.id AS id, r.type AS type, r.properties AS properties,
           source.id AS source_id, target.id AS target_id,
           r.created_at AS created_at, r.updated_at AS updated_at
    """

    params = %{_workspace_id: workspace_id, items: items}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        {:ok, Enum.map(records, &record_to_edge(&1, workspace_id))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def bulk_update_entities(workspace_id, updates, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    items =
      Enum.map(updates, fn update ->
        %{
          id: Map.get(update, :id),
          properties: Map.get(update, :properties, %{}),
          updated_at: now
        }
      end)

    cypher = """
    UNWIND $items AS item
    MATCH (n:Entity {_workspace_id: $_workspace_id, id: item.id})
    WHERE n.deleted_at IS NULL
    SET n.properties = item.properties, n.updated_at = item.updated_at
    RETURN n.id AS id, n.type AS type, n.properties AS properties,
           n.created_at AS created_at, n.updated_at AS updated_at
    """

    params = %{_workspace_id: workspace_id, items: items}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        {:ok, Enum.map(records, &record_to_entity(&1, workspace_id))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def bulk_soft_delete_entities(workspace_id, entity_ids, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    cypher = """
    UNWIND $ids AS entity_id
    MATCH (n:Entity {_workspace_id: $_workspace_id, id: entity_id})
    WHERE n.deleted_at IS NULL
    SET n.deleted_at = $now, n.updated_at = $now
    WITH count(n) AS deleted_count
    RETURN deleted_count
    """

    params = %{_workspace_id: workspace_id, ids: entity_ids, now: now}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: [record | _]}} ->
        {:ok, Map.get(record, "deleted_count", 0)}

      {:ok, %{records: []}} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Batch operations ────────────────────────────────────────────────

  @impl true
  def batch_get_entities(workspace_id, entity_ids, opts \\ []) do
    cypher = """
    UNWIND $ids AS entity_id
    MATCH (n:Entity {_workspace_id: $_workspace_id, id: entity_id})
    WHERE n.deleted_at IS NULL
    RETURN n.id AS id, n.type AS type, n.properties AS properties,
           n.created_at AS created_at, n.updated_at AS updated_at
    """

    params = %{_workspace_id: workspace_id, ids: entity_ids}

    case Neo4jAdapter.execute(cypher, params, opts) do
      {:ok, %{records: records}} ->
        entities_map =
          records
          |> Enum.map(&record_to_entity(&1, workspace_id))
          |> Map.new(fn entity -> {entity.id, entity} end)

        {:ok, entities_map}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Health ──────────────────────────────────────────────────────────

  @impl true
  def health_check(opts \\ []) do
    Neo4jAdapter.health_check(opts)
  end

  # ── Private helpers ──────────────────────────────────────────────────

  defp record_to_entity(record, workspace_id) do
    Entity.new(%{
      id: Map.get(record, "id"),
      workspace_id: workspace_id,
      type: Map.get(record, "type"),
      properties: Map.get(record, "properties", %{}),
      created_at: parse_datetime(Map.get(record, "created_at")),
      updated_at: parse_datetime(Map.get(record, "updated_at")),
      deleted_at: parse_datetime(Map.get(record, "deleted_at"))
    })
  end

  defp record_to_edge(record, workspace_id) do
    Edge.new(%{
      id: Map.get(record, "id"),
      workspace_id: workspace_id,
      type: Map.get(record, "type"),
      source_id: Map.get(record, "source_id"),
      target_id: Map.get(record, "target_id"),
      properties: Map.get(record, "properties", %{}),
      created_at: parse_datetime(Map.get(record, "created_at")),
      updated_at: parse_datetime(Map.get(record, "updated_at")),
      deleted_at: parse_datetime(Map.get(record, "deleted_at"))
    })
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: dt

  defp validate_max_depth!(depth) when is_integer(depth) and depth >= 1 and depth <= 10, do: :ok

  defp validate_max_depth!(depth) do
    raise ArgumentError, "max_depth must be an integer between 1 and 10, got: #{inspect(depth)}"
  end

  defp pagination_params(filters) do
    limit = Map.get(filters, :limit, 100)
    offset = Map.get(filters, :offset, 0)
    {limit, offset}
  end

  defp build_type_filter(%{type: type}) when is_binary(type) do
    {"AND n.type = $filter_type", %{filter_type: type}}
  end

  defp build_type_filter(_), do: {"", %{}}

  defp build_edge_type_filter(%{type: type}) when is_binary(type) do
    {"AND r.type = $filter_type", %{filter_type: type}}
  end

  defp build_edge_type_filter(_), do: {"", %{}}

  defp build_neighbor_pattern("out", edge_type) do
    {"MATCH (start)-[r:EDGE]->(neighbor:Entity)", edge_type_filter(edge_type)}
  end

  defp build_neighbor_pattern("in", edge_type) do
    {"MATCH (start)<-[r:EDGE]-(neighbor:Entity)", edge_type_filter(edge_type)}
  end

  defp build_neighbor_pattern("both", edge_type) do
    {"MATCH (start)-[r:EDGE]-(neighbor:Entity)", edge_type_filter(edge_type)}
  end

  defp build_neighbor_pattern(_, edge_type) do
    {"MATCH (start)-[r:EDGE]-(neighbor:Entity)", edge_type_filter(edge_type)}
  end

  defp edge_type_filter(nil), do: ""
  defp edge_type_filter(_edge_type), do: "AND r.type = $edge_type"

  defp maybe_put_edge_type_param(params, nil), do: params
  defp maybe_put_edge_type_param(params, edge_type), do: Map.put(params, :edge_type, edge_type)
end
