defmodule Jarga.Documents.Queries do
  @moduledoc """
  Query objects for the Documents context.
  Provides composable query functions for building database queries.
  """

  import Ecto.Query
  alias Jarga.Documents.Document
  alias Jarga.Accounts.User
  alias Jarga.Workspaces.WorkspaceMember

  @doc """
  Base query for documents.
  """
  def base do
    from(d in Document, as: :document)
  end

  @doc """
  Filter documents by user.
  Only returns documents owned by the user.
  """
  def for_user(query, %User{id: user_id}) do
    from([document: d] in query,
      where: d.user_id == ^user_id
    )
  end

  @doc """
  Filter documents that are viewable by user.
  Returns documents that are either:
  - Owned by the user, OR
  - Public documents in workspaces where the user is a member
  """
  def viewable_by_user(query, %User{id: user_id}) do
    from([document: d] in query,
      left_join: wm in WorkspaceMember,
      on: wm.workspace_id == d.workspace_id and wm.user_id == ^user_id,
      where: d.user_id == ^user_id or (d.is_public == true and not is_nil(wm.id))
    )
  end

  @doc """
  Filter documents by workspace.
  """
  def for_workspace(query, workspace_id) do
    from([document: d] in query,
      where: d.workspace_id == ^workspace_id
    )
  end

  @doc """
  Filter documents by project.
  """
  def for_project(query, project_id) do
    from([document: d] in query,
      where: d.project_id == ^project_id
    )
  end

  @doc """
  Filter documents by ID.
  """
  def by_id(query, document_id) do
    from([document: d] in query,
      where: d.id == ^document_id
    )
  end

  @doc """
  Filter documents by slug.
  """
  def by_slug(query, slug) do
    from([document: d] in query,
      where: d.slug == ^slug
    )
  end

  @doc """
  Order documents with pinned documents first, then by updated_at (newest first).
  """
  def ordered(query) do
    from([document: d] in query,
      order_by: [desc: d.is_pinned, desc: d.updated_at]
    )
  end

  @doc """
  Preload document components with the document query.
  Uses a join to fetch components in the same query instead of a separate round-trip.
  Components are automatically ordered by position (from schema preload_order).
  """
  def with_components(query) do
    from([document: d] in query,
      preload: [:document_components]
    )
  end
end
