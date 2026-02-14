defmodule EntityRelationshipManager.Application.Behaviours.GraphRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the contract for graph repository operations.

  Implementations provide workspace-scoped entity and edge CRUD,
  traversal, and bulk operations backed by a graph database.
  """

  alias EntityRelationshipManager.Domain.Entities.Entity
  alias EntityRelationshipManager.Domain.Entities.Edge

  # Entity CRUD
  @callback create_entity(workspace_id :: String.t(), type :: String.t(), properties :: map()) ::
              {:ok, Entity.t()} | {:error, term()}

  @callback get_entity(workspace_id :: String.t(), entity_id :: String.t()) ::
              {:ok, Entity.t()} | {:error, :not_found}

  @callback list_entities(workspace_id :: String.t(), filters :: map()) ::
              {:ok, [Entity.t()]}

  @callback update_entity(
              workspace_id :: String.t(),
              entity_id :: String.t(),
              properties :: map()
            ) ::
              {:ok, Entity.t()} | {:error, term()}

  @callback soft_delete_entity(workspace_id :: String.t(), entity_id :: String.t()) ::
              {:ok, Entity.t(), deleted_edge_count :: integer()} | {:error, term()}

  # Edge CRUD
  @callback create_edge(
              workspace_id :: String.t(),
              type :: String.t(),
              source_id :: String.t(),
              target_id :: String.t(),
              properties :: map()
            ) ::
              {:ok, Edge.t()} | {:error, term()}

  @callback get_edge(workspace_id :: String.t(), edge_id :: String.t()) ::
              {:ok, Edge.t()} | {:error, :not_found}

  @callback list_edges(workspace_id :: String.t(), filters :: map()) ::
              {:ok, [Edge.t()]}

  @callback update_edge(workspace_id :: String.t(), edge_id :: String.t(), properties :: map()) ::
              {:ok, Edge.t()} | {:error, term()}

  @callback soft_delete_edge(workspace_id :: String.t(), edge_id :: String.t()) ::
              {:ok, Edge.t()} | {:error, term()}

  # Traversal
  @callback get_neighbors(workspace_id :: String.t(), entity_id :: String.t(), opts :: keyword()) ::
              {:ok, [Entity.t()]}

  @callback find_paths(
              workspace_id :: String.t(),
              source_id :: String.t(),
              target_id :: String.t(),
              opts :: keyword()
            ) ::
              {:ok, [list()]}

  @callback traverse(workspace_id :: String.t(), start_id :: String.t(), opts :: keyword()) ::
              {:ok, [Entity.t()]}

  # Bulk operations
  @callback bulk_create_entities(workspace_id :: String.t(), entities :: [map()]) ::
              {:ok, [Entity.t()]} | {:error, term()}

  @callback bulk_create_edges(workspace_id :: String.t(), edges :: [map()]) ::
              {:ok, [Edge.t()]} | {:error, term()}

  @callback bulk_update_entities(workspace_id :: String.t(), updates :: [map()]) ::
              {:ok, [Entity.t()]} | {:error, term()}

  @callback bulk_soft_delete_entities(workspace_id :: String.t(), entity_ids :: [String.t()]) ::
              {:ok, integer()} | {:error, term()}

  # Health
  @callback health_check() :: :ok | {:error, term()}
end
