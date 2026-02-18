defmodule Jarga.Projects.Application.UseCases.DeleteProject do
  @moduledoc """
  Use case for deleting a project from a workspace.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have permission to delete the project based on their role and ownership
  - Project must exist and belong to the workspace
  - Members can only delete their own projects
  - Admins and owners can delete any project

  ## Responsibilities

  - Validate actor has project access
  - Delete the project
  - Notify workspace members of project deletion
  """

  @behaviour Jarga.Projects.Application.UseCases.UseCase

  alias Identity.Domain.Entities.User
  alias Jarga.Projects.Domain.Events.ProjectDeleted
  alias Jarga.Workspaces
  alias Jarga.Domain.Policies.DomainPermissionsPolicy, as: PermissionsPolicy

  @default_project_repository Jarga.Projects.Infrastructure.Repositories.ProjectRepository
  @default_authorization_repository Jarga.Projects.Infrastructure.Repositories.AuthorizationRepository
  @default_notifier Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Executes the delete project use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User deleting the project
    - `:workspace_id` - ID of the workspace
    - `:project_id` - ID of the project to delete

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service implementation (default: EmailAndPubSubNotifier)

  ## Returns

  - `{:ok, project}` - Project deleted successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      project_id: project_id
    } = params

    project_repository = Keyword.get(opts, :project_repository, @default_project_repository)

    authorization_repository =
      Keyword.get(opts, :authorization_repository, @default_authorization_repository)

    notifier = Keyword.get(opts, :notifier, @default_notifier)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    with {:ok, member} <- get_workspace_member(actor, workspace_id),
         {:ok, project} <-
           verify_project_access(actor, workspace_id, project_id, authorization_repository),
         :ok <- authorize_delete_project(member.role, project, actor.id),
         {:ok, deleted_project} <- delete_project(project, project_repository) do
      notifier.notify_project_deleted(deleted_project, workspace_id)
      emit_project_deleted_event(deleted_project, actor, workspace_id, event_bus)
      {:ok, deleted_project}
    end
  end

  # Get actor's workspace membership
  defp get_workspace_member(%User{} = user, workspace_id) do
    Workspaces.get_member(user, workspace_id)
  end

  # Verify actor has access to the project
  defp verify_project_access(%User{} = user, workspace_id, project_id, authorization_repository) do
    authorization_repository.verify_project_access(user, workspace_id, project_id)
  end

  # Authorize project deletion based on role and ownership
  defp authorize_delete_project(role, project, user_id) do
    owns_project = project.user_id == user_id

    if PermissionsPolicy.can?(role, :delete_project, owns_resource: owns_project) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Emit ProjectDeleted domain event
  defp emit_project_deleted_event(project, actor, workspace_id, event_bus) do
    event =
      ProjectDeleted.new(%{
        aggregate_id: project.id,
        actor_id: actor.id,
        project_id: project.id,
        workspace_id: workspace_id,
        user_id: actor.id
      })

    event_bus.emit(event)
  end

  # Delete the project
  defp delete_project(project_schema, project_repository) do
    project_repository.delete(project_schema)
  end
end
