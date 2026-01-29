defmodule Jarga.Projects.Application.UseCases.UpdateProject do
  @moduledoc """
  Use case for updating a project.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have access to the project
  - Actor must have permission to edit the project (owner or admin, or project creator)
  - Sends notification when project is updated

  ## Responsibilities

  - Validate actor has workspace membership
  - Verify project access
  - Authorize update based on role and ownership
  - Update project attributes
  - Send notification
  """

  @behaviour Jarga.Projects.Application.UseCases.UseCase

  alias Jarga.Workspaces
  alias Jarga.Workspaces.Application.Policies.PermissionsPolicy

  @default_project_repository Jarga.Projects.Infrastructure.Repositories.ProjectRepository
  @default_authorization_repository Jarga.Projects.Infrastructure.Repositories.AuthorizationRepository
  @default_notifier Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier

  @doc """
  Executes the update project use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User updating the project
    - `:workspace_id` - ID of the workspace
    - `:project_id` - ID of the project to update
    - `:attrs` - Project attributes to update

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service (default: EmailAndPubSubNotifier)

  ## Returns

  - `{:ok, project}` - Project updated successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      project_id: project_id,
      attrs: attrs
    } = params

    project_repository = Keyword.get(opts, :project_repository, @default_project_repository)

    authorization_repository =
      Keyword.get(opts, :authorization_repository, @default_authorization_repository)

    notifier = Keyword.get(opts, :notifier, @default_notifier)

    with {:ok, member} <- Workspaces.get_member(actor, workspace_id),
         {:ok, project} <-
           authorization_repository.verify_project_access(actor, workspace_id, project_id),
         :ok <- authorize_edit_project(member.role, project, actor.id) do
      update_project_and_notify(project, attrs, project_repository, notifier)
    end
  end

  # Authorize project edit based on role and ownership
  defp authorize_edit_project(role, project, user_id) do
    owns_project = project.user_id == user_id

    if PermissionsPolicy.can?(role, :edit_project, owns_resource: owns_project) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Update project and send notification
  defp update_project_and_notify(project_schema, attrs, project_repository, notifier) do
    # Convert atom keys to string keys to avoid mixed keys
    string_attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})

    case project_repository.update(project_schema, string_attrs) do
      {:ok, updated_project} ->
        notifier.notify_project_updated(updated_project)
        {:ok, updated_project}

      error ->
        error
    end
  end
end
