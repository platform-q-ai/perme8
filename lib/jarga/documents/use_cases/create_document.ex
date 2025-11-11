defmodule Jarga.Documents.UseCases.CreateDocument do
  @moduledoc """
  Use case for creating a document in a workspace.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have permission to create documents (member, admin, or owner)
  - Document title is optional but slug will be generated if provided
  - Creates a document with an initial note component
  - If project_id is provided, verifies the project belongs to the workspace

  ## Responsibilities

  - Validate actor has workspace membership
  - Validate project belongs to workspace (if provided)
  - Create document, note, and document_component in a transaction
  - Generate unique slug if title is provided
  """

  @behaviour Jarga.Documents.UseCases.UseCase

  alias Ecto.Multi
  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Notes
  alias Jarga.Documents.{Document, DocumentComponent}
  alias Jarga.Documents.Domain.SlugGenerator
  alias Jarga.Documents.Infrastructure.{AuthorizationRepository, DocumentRepository}
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Policies.PermissionsPolicy

  @doc """
  Executes the create document use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User creating the document
    - `:workspace_id` - ID of the workspace
    - `:attrs` - Document attributes (title, project_id, etc.)

  - `opts` - Keyword list of options (currently unused)

  ## Returns

  - `{:ok, document}` - Document created successfully
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
         :ok <- authorize_create_document(member.role),
         :ok <-
           verify_project_in_workspace(workspace_id, Map.get(attrs, :project_id)) do
      create_document_with_note(actor, workspace_id, attrs)
    end
  end

  # Get actor's workspace membership
  defp get_workspace_member(%User{} = user, workspace_id) do
    Workspaces.get_member(user, workspace_id)
  end

  # Authorize document creation based on role
  defp authorize_create_document(role) do
    if PermissionsPolicy.can?(role, :create_document) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Verify project belongs to workspace
  defp verify_project_in_workspace(workspace_id, project_id) do
    AuthorizationRepository.verify_project_in_workspace(workspace_id, project_id)
  end

  # Create the document, note, and document_component in a transaction
  defp create_document_with_note(%User{} = user, workspace_id, attrs) do
    Multi.new()
    |> Multi.run(:note, fn _repo, _changes ->
      note_attrs = %{
        id: Ecto.UUID.generate(),
        project_id: Map.get(attrs, :project_id)
      }

      Notes.create_note(user, workspace_id, note_attrs)
    end)
    |> Multi.run(:document, fn _repo, _changes ->
      # Generate slug in use case (business logic)
      # Only generate slug if title is present
      title = attrs[:title] || attrs["title"]

      attrs_with_user =
        if title do
          slug =
            SlugGenerator.generate(
              title,
              workspace_id,
              &DocumentRepository.slug_exists_in_workspace?/3
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

      %Document{}
      |> Document.changeset(attrs_with_user)
      |> Repo.insert()
    end)
    |> Multi.run(:document_component, fn _repo, %{document: document, note: note} ->
      %DocumentComponent{}
      |> DocumentComponent.changeset(%{
        document_id: document.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{document: document}} -> {:ok, document}
      {:error, :note, reason, _} -> {:error, reason}
      {:error, :document, reason, _} -> {:error, reason}
      {:error, :document_component, reason, _} -> {:error, reason}
    end
  end
end
