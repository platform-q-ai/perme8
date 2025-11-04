defmodule Jarga.Projects.UseCases.CreateProject do
  @moduledoc """
  Use case for creating a project in a workspace.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have permission to create projects (member, admin, or owner)
  - Project name is required and must be valid
  - Generates a unique slug for the project

  ## Responsibilities

  - Validate actor has workspace membership
  - Create project with proper attributes
  - Notify workspace members of new project
  """

  @behaviour Jarga.Projects.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Projects.Project
  alias Jarga.Projects.Services.EmailAndPubSubNotifier
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Policies.PermissionsPolicy

  @doc """
  Executes the create project use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User creating the project
    - `:workspace_id` - ID of the workspace
    - `:attrs` - Project attributes (name, description, etc.)

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service implementation (default: EmailAndPubSubNotifier)

  ## Returns

  - `{:ok, project}` - Project created successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      attrs: attrs
    } = params

    notifier = Keyword.get(opts, :notifier, EmailAndPubSubNotifier)

    with {:ok, member} <- get_workspace_member(actor, workspace_id),
         :ok <- authorize_create_project(member.role),
         {:ok, project} <- create_project(actor, workspace_id, attrs) do
      notifier.notify_project_created(project)
      {:ok, project}
    end
  end

  # Get actor's workspace membership
  defp get_workspace_member(%User{} = user, workspace_id) do
    Workspaces.get_member(user, workspace_id)
  end

  # Authorize project creation based on role
  defp authorize_create_project(role) do
    if PermissionsPolicy.can?(role, :create_project) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Create the project
  defp create_project(%User{} = user, workspace_id, attrs) do
    # Convert atom keys to string keys to avoid mixed keys
    string_attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})
      |> Map.put("user_id", user.id)
      |> Map.put("workspace_id", workspace_id)

    %Project{}
    |> Project.changeset(string_attrs)
    |> Repo.insert()
  end
end
