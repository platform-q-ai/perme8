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
  alias Jarga.Documents.Domain.SlugGenerator
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Application.Policies.PermissionsPolicy

  # Default Infrastructure implementations (injected via opts for testing)
  @default_document_schema Jarga.Documents.Infrastructure.Schemas.DocumentSchema
  @default_document_component_schema Jarga.Documents.Infrastructure.Schemas.DocumentComponentSchema
  @default_note_repository Jarga.Documents.Notes.Infrastructure.Repositories.NoteRepository
  @default_authorization_repository Jarga.Documents.Infrastructure.Repositories.AuthorizationRepository
  @default_document_repository Jarga.Documents.Infrastructure.Repositories.DocumentRepository
  @default_notifier Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier

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

    # Extract dependencies from opts
    document_schema = Keyword.get(opts, :document_schema, @default_document_schema)

    document_component_schema =
      Keyword.get(opts, :document_component_schema, @default_document_component_schema)

    note_repository = Keyword.get(opts, :note_repository, @default_note_repository)

    authorization_repository =
      Keyword.get(opts, :authorization_repository, @default_authorization_repository)

    document_repository = Keyword.get(opts, :document_repository, @default_document_repository)
    notifier = Keyword.get(opts, :notifier, @default_notifier)

    deps = %{
      document_schema: document_schema,
      document_component_schema: document_component_schema,
      note_repository: note_repository,
      document_repository: document_repository,
      notifier: notifier
    }

    with {:ok, member} <- get_workspace_member(actor, workspace_id),
         :ok <- authorize_create_document(member.role),
         :ok <-
           verify_project_in_workspace(
             authorization_repository,
             workspace_id,
             Map.get(attrs, :project_id)
           ) do
      create_document_with_note_and_notify(actor, workspace_id, attrs, deps)
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
  defp verify_project_in_workspace(authorization_repository, workspace_id, project_id) do
    authorization_repository.verify_project_in_workspace(workspace_id, project_id)
  end

  # Create the document, note, and document_component in a transaction
  # Send notification AFTER transaction commits
  defp create_document_with_note_and_notify(%User{} = user, workspace_id, attrs, deps) do
    %{
      document_schema: document_schema,
      document_component_schema: document_component_schema,
      note_repository: note_repository,
      document_repository: document_repository,
      notifier: notifier
    } = deps

    multi =
      Multi.new()
      |> Multi.run(:note, fn _repo, _changes ->
        note_attrs = %{
          id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_id: workspace_id,
          project_id: Map.get(attrs, :project_id)
        }

        note_repository.create(note_attrs)
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
              &document_repository.slug_exists_in_workspace?/3
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

        struct(document_schema)
        |> document_schema.changeset(attrs_with_user)
        |> document_repository.insert()
      end)
      |> Multi.run(:document_component, fn _repo, %{document: document, note: note} ->
        struct(document_component_schema)
        |> document_component_schema.changeset(%{
          document_id: document.id,
          component_type: "note",
          component_id: note.id,
          position: 0
        })
        |> document_repository.insert_component()
      end)

    # Execute transaction through repository
    result = document_repository.transaction(multi)

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
