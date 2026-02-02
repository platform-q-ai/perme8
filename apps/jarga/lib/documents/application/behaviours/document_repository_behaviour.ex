defmodule Jarga.Documents.Application.Behaviours.DocumentRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the document repository contract.
  """

  @type document :: struct()

  @callback slug_exists_in_workspace?(String.t(), Ecto.UUID.t(), Ecto.UUID.t() | nil) :: boolean()
  @callback insert(Ecto.Changeset.t()) :: {:ok, document} | {:error, Ecto.Changeset.t()}
  @callback insert_component(Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback transaction(Ecto.Multi.t()) ::
              {:ok, map()} | {:error, atom(), any(), map()}
end
