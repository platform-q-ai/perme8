defmodule Agents.Application.Behaviours.ErmGatewayBehaviour do
  @moduledoc """
  Behaviour defining the contract for ERM operations.

  Enables mocking in use case tests by abstracting the EntityRelationshipManager
  facade behind a behaviour interface.
  """

  @callback get_schema(workspace_id :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @callback upsert_schema(workspace_id :: String.t(), attrs :: map()) ::
              {:ok, map()} | {:error, term()}

  @callback create_entity(workspace_id :: String.t(), attrs :: map()) ::
              {:ok, map()} | {:error, term()}

  @callback get_entity(workspace_id :: String.t(), entity_id :: String.t()) ::
              {:ok, map()} | {:error, :not_found}

  @callback update_entity(workspace_id :: String.t(), entity_id :: String.t(), attrs :: map()) ::
              {:ok, map()} | {:error, term()}

  @callback list_entities(workspace_id :: String.t(), filters :: map()) ::
              {:ok, [map()]}

  @callback create_edge(workspace_id :: String.t(), attrs :: map()) ::
              {:ok, map()} | {:error, term()}

  @callback list_edges(workspace_id :: String.t(), filters :: map()) ::
              {:ok, [map()]}

  @callback get_neighbors(workspace_id :: String.t(), entity_id :: String.t(), opts :: keyword()) ::
              {:ok, [map()]}

  @callback traverse(workspace_id :: String.t(), start_id :: String.t(), opts :: keyword()) ::
              {:ok, [map()]}
end
