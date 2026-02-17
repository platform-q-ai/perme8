defmodule KnowledgeMcp.Application.Behaviours.ErmGatewayBehaviour do
  @moduledoc """
  Behaviour defining the contract for ERM operations.

  Enables mocking in use case tests by abstracting the EntityRelationshipManager
  facade behind a behaviour interface.
  """

  alias EntityRelationshipManager.Domain.Entities.{Entity, Edge, SchemaDefinition}

  @callback get_schema(workspace_id :: String.t()) ::
              {:ok, SchemaDefinition.t()} | {:error, term()}

  @callback upsert_schema(workspace_id :: String.t(), attrs :: map()) ::
              {:ok, SchemaDefinition.t()} | {:error, term()}

  @callback create_entity(workspace_id :: String.t(), attrs :: map()) ::
              {:ok, Entity.t()} | {:error, term()}

  @callback get_entity(workspace_id :: String.t(), entity_id :: String.t()) ::
              {:ok, Entity.t()} | {:error, :not_found}

  @callback update_entity(workspace_id :: String.t(), entity_id :: String.t(), attrs :: map()) ::
              {:ok, Entity.t()} | {:error, term()}

  @callback list_entities(workspace_id :: String.t(), filters :: map()) ::
              {:ok, [Entity.t()]}

  @callback create_edge(workspace_id :: String.t(), attrs :: map()) ::
              {:ok, Edge.t()} | {:error, term()}

  @callback list_edges(workspace_id :: String.t(), filters :: map()) ::
              {:ok, [Edge.t()]}

  @callback get_neighbors(workspace_id :: String.t(), entity_id :: String.t(), opts :: keyword()) ::
              {:ok, [Entity.t()]}

  @callback traverse(workspace_id :: String.t(), start_id :: String.t(), opts :: keyword()) ::
              {:ok, [Entity.t()]}
end
