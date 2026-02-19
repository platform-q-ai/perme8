defmodule Identity.Application.Behaviours.WorkspaceNotifierBehaviour do
  @moduledoc """
  Behaviour defining the contract for workspace invitation email notifications.
  """

  alias Identity.Domain.Entities.User
  alias Identity.Domain.Entities.Workspace

  @doc """
  Sends an invitation email to an existing user who has been invited to a workspace.
  """
  @callback notify_existing_user(
              user :: User.t(),
              workspace :: Workspace.t(),
              inviter :: User.t()
            ) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Sends an invitation email to a new user (not yet registered) who has been invited to a workspace.
  """
  @callback notify_new_user(email :: String.t(), workspace :: Workspace.t(), inviter :: User.t()) ::
              {:ok, term()} | {:error, term()}
end
