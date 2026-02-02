defmodule Jarga.Chat.Application.Behaviours.MessageRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the message repository contract.
  """

  @type message :: struct()
  @type repo :: module()

  @callback get(Ecto.UUID.t(), repo) :: message | nil
  @callback create_message(map(), repo) :: {:ok, message} | {:error, Ecto.Changeset.t()}
  @callback delete_message(message, repo) :: {:ok, message} | {:error, Ecto.Changeset.t()}
end
