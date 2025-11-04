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
  alias Jarga.Pages.{Page, Queries}
  alias Jarga.Pages.Policies.Authorization
  alias Jarga.Notes

  @doc """
  Gets a single page for a user.

  Only returns the page if it belongs to the user.
  Raises `Ecto.NoResultsError` if the page does not exist or belongs to another user.

  ## Examples

      iex> get_page!(user, page_id)
      %Page{}

      iex> get_page!(user, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_page!(%User{} = user, page_id) do
    Queries.base()
    |> Queries.by_id(page_id)
    |> Queries.for_user(user)
    |> Repo.one!()
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

  The user must be a member of the workspace.
  The page is private to the user who created it.
  A default note is created and embedded in the page.

  ## Examples

      iex> create_page(user, workspace_id, %{title: "My Page"})
      {:ok, %Page{}}

      iex> create_page(user, non_member_workspace_id, %{title: "Page"})
      {:error, :unauthorized}

  """
  def create_page(%User{} = user, workspace_id, attrs) do
    alias Jarga.Pages.PageComponent

    with {:ok, _workspace} <- Authorization.verify_workspace_access(user, workspace_id),
         :ok <- Authorization.verify_project_in_workspace(workspace_id, Map.get(attrs, :project_id)) do
      # Create the page, note, and page_component in a transaction
      Ecto.Multi.new()
      |> Ecto.Multi.run(:note, fn _repo, _changes ->
        note_attrs = %{
          id: Ecto.UUID.generate(),
          project_id: Map.get(attrs, :project_id)
        }

        Notes.create_note(user, workspace_id, note_attrs)
      end)
      |> Ecto.Multi.run(:page, fn _repo, _changes ->
        attrs_with_user = Map.merge(attrs, %{
          user_id: user.id,
          workspace_id: workspace_id,
          created_by: user.id
        })

        %Page{}
        |> Page.changeset(attrs_with_user)
        |> Repo.insert()
      end)
      |> Ecto.Multi.run(:page_component, fn _repo, %{page: page, note: note} ->
        %PageComponent{}
        |> PageComponent.changeset(%{
          page_id: page.id,
          component_type: "note",
          component_id: note.id,
          position: 0
        })
        |> Repo.insert()
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{page: page}} -> {:ok, page}
        {:error, :note, reason, _} -> {:error, reason}
        {:error, :page, reason, _} -> {:error, reason}
        {:error, :page_component, reason, _} -> {:error, reason}
      end
    end
  end

  @doc """
  Updates a page.

  Only the owner of the page can update it.

  ## Examples

      iex> update_page(user, page_id, %{title: "New Title"})
      {:ok, %Page{}}

      iex> update_page(user, page_id, %{title: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_page(user, other_user_page_id, %{title: "Hacked"})
      {:error, :unauthorized}

  """
  def update_page(%User{} = user, page_id, attrs) do
    case Authorization.verify_page_access(user, page_id) do
      {:ok, page} ->
        result = page
        |> Page.changeset(attrs)
        |> Repo.update()

        # Broadcast changes to workspace members
        case result do
          {:ok, updated_page} ->
            if Map.has_key?(attrs, :is_public) and attrs.is_public != page.is_public do
              broadcast_page_visibility_change(updated_page)
            end
            if Map.has_key?(attrs, :title) and attrs.title != page.title do
              broadcast_page_title_change(updated_page)
            end
            {:ok, updated_page}

          error ->
            error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a page.

  Only the owner of the page can delete it.
  Deleting a page also deletes its embedded note.

  ## Examples

      iex> delete_page(user, page_id)
      {:ok, %Page{}}

      iex> delete_page(user, other_user_page_id)
      {:error, :unauthorized}

  """
  def delete_page(%User{} = user, page_id) do
    case Authorization.verify_page_access(user, page_id) do
      {:ok, page} ->
        Repo.delete(page)

      {:error, reason} ->
        {:error, reason}
    end
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

  # Private functions

  defp broadcast_page_visibility_change(page) do
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{page.workspace_id}",
      {:page_visibility_changed, page.id, page.is_public}
    )
  end

  defp broadcast_page_title_change(page) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{page.workspace_id}",
      {:page_title_changed, page.id, page.title}
    )

    # Also broadcast to the page itself for page show view
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "page:#{page.id}",
      {:page_title_changed, page.id, page.title}
    )
  end
end
