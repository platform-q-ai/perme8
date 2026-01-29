defmodule Jarga.Documents.Application.Behaviours.DocumentSchemaBehaviour do
  @moduledoc """
  Behaviour defining the document schema contract.
  """

  @callback changeset(struct(), map()) :: Ecto.Changeset.t()
end
