defmodule Jarga.Projects.Application.UseCases.CreateProject do
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

  @behaviour Jarga.Projects.Application.UseCases.UseCase

  alias Identity.Domain.Entities.User
  alias Jarga.Projects.Domain.Events.ProjectCreated
  alias Jarga.Projects.Domain.SlugGenerator
  alias Jarga.Workspaces
  alias Jarga.Domain.Policies.DomainPermissionsPolicy, as: PermissionsPolicy

  @default_project_repository Jarga.Projects.Infrastructure.Repositories.ProjectRepository
  @default_notifier Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier
  @default_event_bus Perme8.Events.EventBus

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

    project_repository = Keyword.get(opts, :project_repository, @default_project_repository)
    notifier = Keyword.get(opts, :notifier, @default_notifier)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    with {:ok, member} <- get_workspace_member(actor, workspace_id),
         :ok <- authorize_create_project(member.role),
         {:ok, project} <- create_project(actor, workspace_id, attrs, project_repository) do
      notifier.notify_project_created(project)
      emit_project_created_event(project, actor, workspace_id, event_bus)
      {:ok, project}
    end
  end

  # Emit ProjectCreated domain event
  defp emit_project_created_event(project, actor, workspace_id, event_bus) do
    event =
      ProjectCreated.new(%{
        aggregate_id: project.id,
        actor_id: actor.id,
        project_id: project.id,
        workspace_id: workspace_id,
        user_id: actor.id,
        name: project.name,
        slug: project.slug
      })

    event_bus.emit(event)
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
  defp create_project(%User{} = user, workspace_id, attrs, project_repository) do
    # Convert atom keys to string keys to avoid mixed keys
    string_attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})
      |> Map.put("user_id", user.id)
      |> Map.put("workspace_id", workspace_id)

    # Generate slug in use case (business logic) - fixed Credo violation
    # Only generate slug if name is present and slug is not already provided
    string_attrs =
      if string_attrs["name"] && !string_attrs["slug"] do
        slug =
          SlugGenerator.generate(
            string_attrs["name"],
            workspace_id,
            &project_repository.slug_exists_in_workspace?/3
          )

        Map.put(string_attrs, "slug", slug)
      else
        string_attrs
      end

    project_repository.insert(string_attrs)
  end
end
