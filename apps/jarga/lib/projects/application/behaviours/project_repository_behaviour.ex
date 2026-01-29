defmodule Jarga.Projects.Application.Behaviours.ProjectRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the project repository contract.
  """

  @type project :: struct()
  @type repo :: module()

  @callback insert(map(), repo) :: {:ok, project} | {:error, Ecto.Changeset.t()}
  @callback update(struct(), map(), repo) :: {:ok, project} | {:error, Ecto.Changeset.t()}
  @callback delete(struct(), repo) :: {:ok, project} | {:error, Ecto.Changeset.t()}
  @callback slug_exists_in_workspace?(String.t(), Ecto.UUID.t(), Ecto.UUID.t() | nil, repo) ::
              boolean()
end
