defmodule Jarga.Accounts.Application.Behaviours.UserRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the user repository contract.
  """

  alias Jarga.Accounts.Domain.Entities.User

  @type repo :: module()

  @callback insert_changeset(Ecto.Changeset.t(), repo) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  @callback update_changeset(Ecto.Changeset.t(), repo) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}
end
