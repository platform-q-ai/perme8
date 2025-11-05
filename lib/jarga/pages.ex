defmodule Jarga.Pages do
  @moduledoc """
  The Pages context.

  Handles page creation, management, and embedded notes.
  Pages are private to the user who created them, regardless of workspace membership.
  Each page has an embedded note for collaborative editing.
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Exports: Main context module and shared types (Page)
  # Internal modules (Queries, Policies) remain private
  use Boundary,
    top_level?: true,
    deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Projects, Jarga.Notes, Jarga.Repo],
    exports: [{Page, []}]

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Notes
  alias Jarga.Pages.{Page, Queries}
  alias Jarga.Pages.UseCases

  @doc """
  Gets a single page for a user.

  Only returns the page if it belongs to the user.
  Raises `Ecto.NoResultsError` if the page does not exist or belongs to another user.

  ## Options

    * `:preload_components` - If true, preloads page_components association. Defaults to false.

  ## Examples

      iex> get_page!(user, page_id)
      %Page{}

      iex> get_page!(user, page_id, preload_components: true)
      %Page{page_components: [...]}

      iex> get_page!(user, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_page!(%User{} = user, page_id, opts \\ []) do
    page =
      Queries.base()
      |> Queries.by_id(page_id)
      |> Queries.for_user(user)
      |> Repo.one!()

    if Keyword.get(opts, :preload_components, false) do
      Repo.preload(page, :page_components)
    else
      page
    end
  end

  @doc """
  Gets a single page by slug for a user in a workspace.

  Returns {:ok, page} or {:error, :page_not_found}

  ## Examples

      iex> get_page_by_slug(user, workspace_id, "my-page")
      {:ok, %Page{}}

      iex> get_page_by_slug(user, workspace_id, "nonexistent")
      {:error, :page_not_found}

  """
  def get_page_by_slug(%User{} = user, workspace_id, slug) do
    page =
      Queries.base()
      |> Queries.by_slug(slug)
      |> Queries.for_workspace(workspace_id)
      |> Queries.viewable_by_user(user)
      |> Queries.with_components()
      |> Repo.one()

    case page do
      nil -> {:error, :page_not_found}
      page -> {:ok, page}
    end
  end

  @doc """
  Gets a single page by slug for a user in a workspace.

  Only returns the page if it belongs to the user.
  Raises `Ecto.NoResultsError` if the page does not exist with that slug or belongs to another user.

  ## Examples

      iex> get_page_by_slug!(user, workspace_id, "my-page")
      %Page{}

      iex> get_page_by_slug!(user, workspace_id, "nonexistent")
      ** (Ecto.NoResultsError)

  """
  def get_page_by_slug!(%User{} = user, workspace_id, slug) do
    Queries.base()
    |> Queries.by_slug(slug)
    |> Queries.for_workspace(workspace_id)
    |> Queries.viewable_by_user(user)
    |> Repo.one!()
  end

  @doc """
  Creates a page for a user in a workspace.

  The user must be a member of the workspace with permission to create pages.
  Members, admins, and owners can create pages. Guests cannot.
  The page is private to the user who created it.
  A default note is created and embedded in the page.

  ## Examples

      iex> create_page(user, workspace_id, %{title: "My Page"})
      {:ok, %Page{}}

      iex> create_page(user, non_member_workspace_id, %{title: "Page"})
      {:error, :unauthorized}

      iex> create_page(guest, workspace_id, %{title: "Page"})
      {:error, :forbidden}

  """
  def create_page(%User{} = user, workspace_id, attrs) do
    UseCases.CreatePage.execute(%{
      actor: user,
      workspace_id: workspace_id,
      attrs: attrs
    })
  end

  @doc """
  Updates a page.

  Permission rules:
  - Users can edit their own pages
  - Members and admins can edit shared (public) pages
  - Admins can only edit shared pages, not private pages of others
  - Owners cannot edit pages they don't own (respects privacy)
  - Pinning follows the same rules as editing

  ## Examples

      iex> update_page(user, page_id, %{title: "New Title"})
      {:ok, %Page{}}

      iex> update_page(user, page_id, %{title: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_page(member, other_user_private_page_id, %{title: "Hacked"})
      {:error, :forbidden}

      iex> update_page(member, other_user_public_page_id, %{title: "Edit"})
      {:ok, %Page{}}

      iex> update_page(member, other_user_public_page_id, %{is_pinned: true})
      {:ok, %Page{}}

  """
  def update_page(%User{} = user, page_id, attrs, opts \\ []) do
    UseCases.UpdatePage.execute(
      %{
        actor: user,
        page_id: page_id,
        attrs: attrs
      },
      opts
    )
  end

  @doc """
  Deletes a page.

  Permission rules:
  - Users can delete their own pages
  - Admins can delete shared (public) pages
  - Admins cannot delete private pages of others
  - Owners cannot delete pages they don't own (respects privacy)
  Deleting a page also deletes its embedded note.

  ## Examples

      iex> delete_page(user, page_id)
      {:ok, %Page{}}

      iex> delete_page(member, other_user_page_id)
      {:error, :forbidden}

      iex> delete_page(admin, other_user_public_page_id)
      {:ok, %Page{}}

  """
  def delete_page(%User{} = user, page_id) do
    UseCases.DeletePage.execute(%{
      actor: user,
      page_id: page_id
    })
  end

  @doc """
  Lists all pages viewable by a user in a workspace.

  Returns pages that are either:
  - Created by the user, OR
  - Public pages created by other workspace members

  ## Examples

      iex> list_pages_for_workspace(user, workspace_id)
      [%Page{}, ...]

  """
  def list_pages_for_workspace(%User{} = user, workspace_id) do
    Queries.base()
    |> Queries.for_workspace(workspace_id)
    |> Queries.viewable_by_user(user)
    |> Queries.ordered()
    |> Repo.all()
  end

  @doc """
  Lists all pages viewable by a user in a project.

  Returns pages that are either:
  - Created by the user, OR
  - Public pages created by other workspace members

  ## Examples

      iex> list_pages_for_project(user, workspace_id, project_id)
      [%Page{}, ...]

  """
  def list_pages_for_project(%User{} = user, workspace_id, project_id) do
    Queries.base()
    |> Queries.for_workspace(workspace_id)
    |> Queries.for_project(project_id)
    |> Queries.viewable_by_user(user)
    |> Queries.ordered()
    |> Repo.all()
  end

  @doc """
  Gets the note component from a page.

  Returns the Note associated with the first note component in the page.
  Raises if the page has no note component.

  ## Examples

      iex> get_page_note(page)
      %Note{}

  """
  def get_page_note(%Page{page_components: page_components}) do
    case Enum.find(page_components, fn pc -> pc.component_type == "note" end) do
      %{component_id: note_id} ->
        case Notes.get_note_by_id(note_id) do
          nil -> raise "Note not found: #{note_id}"
          note -> note
        end

      nil ->
        raise "Page has no note component"
    end
  end
end
