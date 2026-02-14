defmodule Identity.Application.Behaviours.MembershipRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the workspace membership repository contract.
  """

  alias Identity.Domain.Entities.User
  alias Identity.Domain.Entities.{Workspace, WorkspaceMember}

  @callback get_workspace_for_user(User.t(), Ecto.UUID.t()) :: Workspace.t() | nil
  @callback workspace_exists?(Ecto.UUID.t()) :: boolean()
  @callback find_member_by_email(Ecto.UUID.t(), String.t()) :: WorkspaceMember.t() | nil
  @callback email_is_member?(Ecto.UUID.t(), String.t()) :: boolean()
  @callback get_member(User.t(), Ecto.UUID.t()) :: WorkspaceMember.t() | nil
  @callback update_member(WorkspaceMember.t(), map()) ::
              {:ok, WorkspaceMember.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_member(WorkspaceMember.t()) ::
              {:ok, WorkspaceMember.t()} | {:error, Ecto.Changeset.t()}
  @callback create_member(map()) ::
              {:ok, WorkspaceMember.t()} | {:error, Ecto.Changeset.t()}
  @callback transact(function()) :: {:ok, any()} | {:error, any()}
end
