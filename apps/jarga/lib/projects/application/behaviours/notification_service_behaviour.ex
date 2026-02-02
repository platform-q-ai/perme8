defmodule Jarga.Projects.Application.Behaviours.NotificationServiceBehaviour do
  @moduledoc """
  Behavior for project notification services.

  Defines the contract for sending notifications when projects are created or deleted.
  This allows for dependency injection and easier testing with mock implementations.
  """

  alias Jarga.Projects.Domain.Entities.Project

  @doc """
  Notifies workspace members that a project has been created.
  """
  @callback notify_project_created(project :: Project.t()) ::
              :ok | {:error, term()}

  @doc """
  Notifies workspace members that a project has been deleted.
  """
  @callback notify_project_deleted(project :: Project.t(), workspace_id :: Ecto.UUID.t()) ::
              :ok | {:error, term()}

  @doc """
  Notifies workspace members that a project has been updated.
  """
  @callback notify_project_updated(project :: Project.t()) ::
              :ok | {:error, term()}
end
