defmodule EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository do
  @moduledoc """
  PostgreSQL-backed repository for workspace schema definitions.

  Implements `SchemaRepositoryBehaviour` using Ecto and the `entity_schemas` table.
  Supports workspace-scoped retrieval and upsert with optimistic locking.
  """

  @behaviour EntityRelationshipManager.Application.Behaviours.SchemaRepositoryBehaviour

  import Ecto.Query

  alias EntityRelationshipManager.Infrastructure.Schemas.SchemaDefinitionSchema

  defp repo, do: Application.get_env(:entity_relationship_manager, :ecto_repo, Jarga.Repo)

  @impl true
  def get_schema(workspace_id) do
    query =
      from(s in SchemaDefinitionSchema,
        where: s.workspace_id == ^workspace_id
      )

    case repo().one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, SchemaDefinitionSchema.to_entity(schema)}
    end
  end

  @impl true
  def upsert_schema(workspace_id, attrs) do
    case find_existing(workspace_id) do
      nil -> create_schema(workspace_id, attrs)
      existing -> update_schema(existing, attrs)
    end
  end

  defp find_existing(workspace_id) do
    query =
      from(s in SchemaDefinitionSchema,
        where: s.workspace_id == ^workspace_id
      )

    repo().one(query)
  end

  defp create_schema(workspace_id, attrs) do
    create_attrs = Map.put(attrs, :workspace_id, workspace_id)

    %SchemaDefinitionSchema{}
    |> SchemaDefinitionSchema.create_changeset(create_attrs)
    |> repo().insert()
    |> handle_result()
  end

  defp update_schema(existing, attrs) do
    # When version is nil (e.g., setup/idempotent upsert), skip optimistic locking
    # by using a force changeset that just sets the fields without version check
    changeset =
      if is_nil(attrs[:version]) do
        SchemaDefinitionSchema.force_update_changeset(existing, attrs)
      else
        SchemaDefinitionSchema.update_changeset(existing, attrs)
      end

    changeset
    |> repo().update()
    |> handle_result()
  end

  defp handle_result({:ok, schema}) do
    {:ok, SchemaDefinitionSchema.to_entity(schema)}
  end

  defp handle_result({:error, %Ecto.Changeset{} = changeset}) do
    if stale_error?(changeset) do
      {:error, :stale}
    else
      {:error, changeset}
    end
  end

  defp stale_error?(%Ecto.Changeset{errors: errors}) do
    Keyword.has_key?(errors, :version)
  end
end
