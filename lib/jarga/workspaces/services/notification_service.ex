defmodule Jarga.Workspaces.Services.NotificationService do
  @moduledoc """
  Behavior for workspace notification services.

  Defines the contract for sending notifications when workspace members are invited.
  This allows for dependency injection and easier testing with mock implementations.
  """

  alias Jarga.Accounts.User
  alias Jarga.Workspaces.Workspace

  @doc """
  Notifies an existing user that they've been added to a workspace.
  """
  @callback notify_existing_user(user :: User.t(), workspace :: Workspace.t(), inviter :: User.t()) ::
              :ok | {:error, term()}

  @doc """
  Notifies a new user (via email) that they've been invited to a workspace.
  """
  @callback notify_new_user(email :: String.t(), workspace :: Workspace.t(), inviter :: User.t()) ::
              :ok | {:error, term()}
end
