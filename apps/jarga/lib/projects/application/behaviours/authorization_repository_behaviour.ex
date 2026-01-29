defmodule Jarga.Projects.Application.Behaviours.AuthorizationRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the project authorization repository contract.
  """

  alias Jarga.Accounts.Domain.Entities.User

  @callback verify_project_access(User.t(), Ecto.UUID.t(), Ecto.UUID.t(), module()) ::
              {:ok, struct()} | {:error, atom()}
end
