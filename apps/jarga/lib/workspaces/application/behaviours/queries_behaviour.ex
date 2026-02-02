defmodule Jarga.Workspaces.Application.Behaviours.QueriesBehaviour do
  @moduledoc """
  Behaviour defining the workspace queries contract.
  """

  @callback find_pending_invitations_by_email(String.t()) :: Ecto.Query.t()
  @callback with_workspace_and_inviter(Ecto.Query.t()) :: Ecto.Query.t()
end
