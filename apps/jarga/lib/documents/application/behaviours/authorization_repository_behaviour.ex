defmodule Jarga.Documents.Application.Behaviours.AuthorizationRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the document authorization repository contract.
  """

  @callback verify_project_in_workspace(Ecto.UUID.t(), Ecto.UUID.t() | nil) ::
              :ok | {:error, term()}
end
