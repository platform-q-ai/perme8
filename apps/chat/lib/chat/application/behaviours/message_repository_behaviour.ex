defmodule Chat.Application.Behaviours.MessageRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the message repository contract.
  """

  @type message :: struct()

  @callback get(Ecto.UUID.t()) :: message | nil
  @callback create_message(map()) :: {:ok, message} | {:error, Ecto.Changeset.t()}
  @callback delete_message(message) :: {:ok, message} | {:error, Ecto.Changeset.t()}
end
