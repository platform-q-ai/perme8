defmodule Jarga.Pages.UseCases.CreatePage do
  @moduledoc """
  Use case for creating a page in a workspace.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have permission to create pages (member, admin, or owner)
  - Page title is optional but slug will be generated if provided
  - Creates a page with an initial note component
  - If project_id is provided, verifies the project belongs to the workspace

  ## Responsibilities

  - Validate actor has workspace membership
  - Validate project belongs to workspace (if provided)
  - Create page, note, and page_component in a transaction
  - Generate unique slug if title is provided
  """

  @behaviour Jarga.Pages.UseCases.UseCase

  alias Ecto.Multi
  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Notes
  alias Jarga.Pages.{Page, PageComponent}
  alias Jarga.Pages.Domain.SlugGenerator
  alias Jarga.Pages.Infrastructure.{AuthorizationRepository, PageRepository}
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Policies.PermissionsPolicy

  @doc """
  Executes the create page use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User creating the page
    - `:workspace_id` - ID of the workspace
    - `:attrs` - Page attributes (title, project_id, etc.)

  - `opts` - Keyword list of options (currently unused)

  ## Returns

  - `{:ok, page}` - Page created successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, _opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      attrs: attrs
    } = params

    with {:ok, member} <- get_workspace_member(actor, workspace_id),
         :ok <- authorize_create_page(member.role),
         :ok <-
           verify_project_in_workspace(workspace_id, Map.get(attrs, :project_id)) do
      create_page_with_note(actor, workspace_id, attrs)
    end
  end

  # Get actor's workspace membership
  defp get_workspace_member(%User{} = user, workspace_id) do
    Workspaces.get_member(user, workspace_id)
  end

  # Authorize page creation based on role
  defp authorize_create_page(role) do
    if PermissionsPolicy.can?(role, :create_page) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Verify project belongs to workspace
  defp verify_project_in_workspace(workspace_id, project_id) do
    AuthorizationRepository.verify_project_in_workspace(workspace_id, project_id)
  end

  # Create the page, note, and page_component in a transaction
  defp create_page_with_note(%User{} = user, workspace_id, attrs) do
    Multi.new()
    |> Multi.run(:note, fn _repo, _changes ->
      note_attrs = %{
        id: Ecto.UUID.generate(),
        project_id: Map.get(attrs, :project_id)
      }

      Notes.create_note(user, workspace_id, note_attrs)
    end)
    |> Multi.run(:page, fn _repo, _changes ->
      # Generate slug in use case (business logic)
      # Only generate slug if title is present
      title = attrs[:title] || attrs["title"]

      attrs_with_user =
        if title do
          slug =
            SlugGenerator.generate(
              title,
              workspace_id,
              &PageRepository.slug_exists_in_workspace?/3
            )

          Map.merge(attrs, %{
            user_id: user.id,
            workspace_id: workspace_id,
            created_by: user.id,
            slug: slug
          })
        else
          Map.merge(attrs, %{
            user_id: user.id,
            workspace_id: workspace_id,
            created_by: user.id
          })
        end

      %Page{}
      |> Page.changeset(attrs_with_user)
      |> Repo.insert()
    end)
    |> Multi.run(:page_component, fn _repo, %{page: page, note: note} ->
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
