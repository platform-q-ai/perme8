defmodule Jarga.Pages.Infrastructure.PageRepository do
  @moduledoc """
  Infrastructure layer for Page data access.
  Provides database query functions for pages.
  """

  import Ecto.Query
  alias Jarga.Repo
  alias Jarga.Pages.Page

  @doc """
  Checks if a slug already exists within a workspace, optionally excluding a specific page.

  Used by SlugGenerator to ensure uniqueness.
  """
  def slug_exists_in_workspace?(slug, workspace_id, excluding_id \\ nil) do
    query =
      from(p in Page,
        where: p.slug == ^slug and p.workspace_id == ^workspace_id
      )

    query =
      if excluding_id do
        from(p in query, where: p.id != ^excluding_id)
      else
        query
      end

    Repo.exists?(query)
  end
end
