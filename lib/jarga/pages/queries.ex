defmodule Jarga.Pages.Queries do
  @moduledoc """
  Query objects for the Pages context.
  Provides composable query functions for building database queries.
  """

  import Ecto.Query
  alias Jarga.Pages.Page
  alias Jarga.Accounts.User
  alias Jarga.Workspaces.WorkspaceMember

  @doc """
  Base query for pages.
  """
  def base do
    from p in Page, as: :page
  end

  @doc """
  Filter pages by user.
  Only returns pages owned by the user.
  """
  def for_user(query, %User{id: user_id}) do
    from [page: p] in query,
      where: p.user_id == ^user_id
  end

  @doc """
  Filter pages that are viewable by user.
  Returns pages that are either:
  - Owned by the user, OR
  - Public pages in workspaces where the user is a member
  """
  def viewable_by_user(query, %User{id: user_id}) do
    from [page: p] in query,
      left_join: wm in WorkspaceMember,
      on: wm.workspace_id == p.workspace_id and wm.user_id == ^user_id,
      where: p.user_id == ^user_id or (p.is_public == true and not is_nil(wm.id))
  end

  @doc """
  Filter pages by workspace.
  """
  def for_workspace(query, workspace_id) do
    from [page: p] in query,
      where: p.workspace_id == ^workspace_id
  end

  @doc """
  Filter pages by project.
  """
  def for_project(query, project_id) do
    from [page: p] in query,
      where: p.project_id == ^project_id
  end

  @doc """
  Filter pages by ID.
  """
  def by_id(query, page_id) do
    from [page: p] in query,
      where: p.id == ^page_id
  end

  @doc """
  Filter pages by slug.
  """
  def by_slug(query, slug) do
    from [page: p] in query,
      where: p.slug == ^slug
  end

  @doc """
  Order pages with pinned pages first, then by updated_at (newest first).
  """
  def ordered(query) do
    from [page: p] in query,
      order_by: [desc: p.is_pinned, desc: p.updated_at]
  end
end
