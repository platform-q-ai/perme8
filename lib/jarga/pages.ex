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
  alias Jarga.Pages.Policies.Authorization
  alias Jarga.Pages.Services.PubSubNotifier
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Policies.PermissionsPolicy

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
      |> Repo.one()

    case page do
      nil -> {:error, :page_not_found}
      page -> {:ok, Repo.preload(page, :page_components)}
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
    alias Jarga.Pages.PageComponent

    with {:ok, member} <- Workspaces.get_member(user, workspace_id),
         :ok <- authorize_create_page(member.role),
         :ok <-
           Authorization.verify_project_in_workspace(workspace_id, Map.get(attrs, :project_id)) do
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
        attrs_with_user =
          Map.merge(attrs, %{
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
    # Get notifier from opts or use default
    notifier = Keyword.get(opts, :notifier, PubSubNotifier)

    with {:ok, page} <- get_page_with_workspace_member(user, page_id),
         {:ok, member} <- Workspaces.get_member(user, page.workspace_id),
         :ok <- authorize_page_update(member.role, page, user.id, attrs) do
      result =
        page
        |> Page.changeset(attrs)
        |> Repo.update()

      # Notify workspace members via injected notifier
      case result do
        {:ok, updated_page} ->
          if Map.has_key?(attrs, :is_public) and attrs.is_public != page.is_public do
            notifier.notify_page_visibility_changed(updated_page)
          end

          if Map.has_key?(attrs, :is_pinned) and attrs.is_pinned != page.is_pinned do
            notifier.notify_page_pinned_changed(updated_page)
          end

          if Map.has_key?(attrs, :title) and attrs.title != page.title do
            notifier.notify_page_title_changed(updated_page)
          end

          {:ok, updated_page}

        error ->
          error
      end
    end
  end

  defp authorize_page_update(role, page, user_id, attrs) do
    owns_page = page.user_id == user_id

    # If updating is_pinned, check pin permissions
    if Map.has_key?(attrs, :is_pinned) do
      if PermissionsPolicy.can?(role, :pin_page,
           owns_resource: owns_page,
           is_public: page.is_public
         ) do
        :ok
      else
        {:error, :forbidden}
      end
    else
      # Otherwise check edit permissions
      if PermissionsPolicy.can?(role, :edit_page,
           owns_resource: owns_page,
           is_public: page.is_public
         ) do
        :ok
      else
        {:error, :forbidden}
      end
    end
  end

  defp get_page_with_workspace_member(user, page_id) do
    # First get the page without user filter to check if it exists
    page =
      Queries.base()
      |> Queries.by_id(page_id)
      |> Repo.one()

    case page do
      nil ->
        {:error, :page_not_found}

      page ->
        # Check if user is a workspace member
        case Workspaces.verify_membership(user, page.workspace_id) do
          {:ok, _workspace} ->
            # Check if user can view this page (own or public)
            if page.user_id == user.id or page.is_public do
              {:ok, page}
            else
              # User is a member but can't view this private page
              {:error, :forbidden}
            end

          {:error, _reason} ->
            # User is not a workspace member
            {:error, :unauthorized}
        end
    end
  end

  defp authorize_create_page(role) do
    if PermissionsPolicy.can?(role, :create_page) do
      :ok
    else
      {:error, :forbidden}
    end
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
    with {:ok, page} <- get_page_with_workspace_member(user, page_id),
         {:ok, member} <- Workspaces.get_member(user, page.workspace_id),
         :ok <- authorize_delete_page(member.role, page, user.id) do
      Repo.delete(page)
    end
  end

  defp authorize_delete_page(role, page, user_id) do
    owns_page = page.user_id == user_id

    # For delete, we need to check if it's public when not the owner
    if owns_page do
      if PermissionsPolicy.can?(role, :delete_page, owns_resource: true) do
        :ok
      else
        {:error, :forbidden}
      end
    else
      if PermissionsPolicy.can?(role, :delete_page,
           owns_resource: false,
           is_public: page.is_public
         ) do
        :ok
      else
        {:error, :forbidden}
      end
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
        Repo.get!(Jarga.Notes.Note, note_id)

      nil ->
        raise "Page has no note component"
    end
  end
end
