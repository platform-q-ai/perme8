defmodule EntityRelationshipManager.Application.Behaviours.SchemaRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the contract for schema repository operations.

  Implementations provide workspace-scoped schema storage and retrieval.
  """

  alias EntityRelationshipManager.Domain.Entities.SchemaDefinition

  @callback get_schema(workspace_id :: String.t()) ::
              {:ok, SchemaDefinition.t()} | {:error, :not_found}

  @callback upsert_schema(workspace_id :: String.t(), attrs :: map()) ::
              {:ok, SchemaDefinition.t()} | {:error, term()}
end
