defmodule Jarga.Documents.Application.UseCases.CreateDocument do
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

  @behaviour Jarga.Documents.Application.UseCases.UseCase

  alias Ecto.Multi
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Notes
  alias Jarga.Documents.Infrastructure.Schemas.{DocumentSchema, DocumentComponentSchema}
  alias Jarga.Documents.Domain.SlugGenerator
  alias Jarga.Documents.Infrastructure.Repositories.AuthorizationRepository
  alias Jarga.Documents.Infrastructure.Repositories.DocumentRepository
  alias Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Application.Policies.PermissionsPolicy

  @doc """
  Executes the create document use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User creating the document
    - `:workspace_id` - ID of the workspace
    - `:attrs` - Document attributes (title, project_id, etc.)

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service (default: PubSubNotifier)

  ## Returns

  - `{:ok, document}` - Document created successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      attrs: attrs
    } = params

    notifier = Keyword.get(opts, :notifier, PubSubNotifier)

    with {:ok, member} <- get_workspace_member(actor, workspace_id),
         :ok <- authorize_create_document(member.role),
         :ok <-
           verify_project_in_workspace(workspace_id, Map.get(attrs, :project_id)) do
      create_document_with_note_and_notify(actor, workspace_id, attrs, notifier)
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
  # Send notification AFTER transaction commits
  defp create_document_with_note_and_notify(%User{} = user, workspace_id, attrs, notifier) do
    multi =
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
        # Title is required - will fail validation if not provided
        title = attrs[:title] || attrs["title"]

        slug =
          if title do
            SlugGenerator.generate(
              title,
              workspace_id,
              &DocumentRepository.slug_exists_in_workspace?/3
            )
          else
            # If no title provided, slug will be nil and validation will fail
            nil
          end

        attrs_with_user =
          Map.merge(attrs, %{
            user_id: user.id,
            workspace_id: workspace_id,
            created_by: user.id,
            slug: slug
          })

        %DocumentSchema{}
        |> DocumentSchema.changeset(attrs_with_user)
        |> DocumentRepository.insert()
      end)
      |> Multi.run(:document_component, fn _repo, %{document: document, note: note} ->
        %DocumentComponentSchema{}
        |> DocumentComponentSchema.changeset(%{
          document_id: document.id,
          component_type: "note",
          component_id: note.id,
          position: 0
        })
        |> DocumentRepository.insert_component()
      end)

    # Execute transaction through repository
    result = DocumentRepository.transaction(multi)

    case result do
      {:ok, %{document: document}} ->
        # Send notification AFTER transaction commits successfully
        notifier.notify_document_created(document)
        {:ok, document}

      {:error, :note, reason, _} ->
        {:error, reason}

      {:error, :document, reason, _} ->
        {:error, reason}

      {:error, :document_component, reason, _} ->
        {:error, reason}
    end
  end
end
