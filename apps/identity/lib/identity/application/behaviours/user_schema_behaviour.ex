defmodule Identity.Application.Behaviours.UserSchemaBehaviour do
  @moduledoc """
  Behaviour defining the user schema contract.
  """

  alias Identity.Domain.Entities.User

  @callback password_changeset(User.t() | struct(), map(), keyword()) :: Ecto.Changeset.t()
  @callback email_changeset(User.t() | struct(), map(), keyword()) :: Ecto.Changeset.t()
  @callback confirm_changeset(User.t() | struct()) :: Ecto.Changeset.t()
  @callback registration_changeset(struct(), map(), keyword()) :: Ecto.Changeset.t()
end
