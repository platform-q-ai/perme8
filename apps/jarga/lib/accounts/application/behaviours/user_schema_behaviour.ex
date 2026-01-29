defmodule Jarga.Accounts.Application.Behaviours.UserSchemaBehaviour do
  @moduledoc """
  Behaviour defining the user schema contract.
  """

  alias Jarga.Accounts.Domain.Entities.User

  @callback password_changeset(User.t() | struct(), map()) :: Ecto.Changeset.t()
  @callback email_changeset(User.t() | struct(), map()) :: Ecto.Changeset.t()
  @callback confirm_changeset(User.t() | struct()) :: Ecto.Changeset.t()
  @callback registration_changeset(struct(), map()) :: Ecto.Changeset.t()
end
