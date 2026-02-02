defmodule Jarga.Documents.Application.Behaviours.DocumentComponentSchemaBehaviour do
  @moduledoc """
  Behaviour defining the document component schema contract.
  """

  @callback changeset(struct(), map()) :: Ecto.Changeset.t()
end
