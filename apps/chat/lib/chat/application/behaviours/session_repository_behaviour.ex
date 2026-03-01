defmodule Chat.Application.Behaviours.SessionRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the session repository contract.
  """

  @type session :: struct()
  @type message :: struct()

  @callback get_session_by_id(Ecto.UUID.t()) :: session | nil
  @callback get_session_by_id_and_user(Ecto.UUID.t(), Ecto.UUID.t()) :: session | nil
  @callback list_user_sessions(Ecto.UUID.t(), non_neg_integer()) :: list(map())
  @callback get_first_message_content(Ecto.UUID.t()) :: String.t() | nil
  @callback get_message_by_id_and_user(Ecto.UUID.t(), Ecto.UUID.t()) :: message | nil
  @callback create_session(map()) :: {:ok, session} | {:error, Ecto.Changeset.t()}
  @callback delete_session(session) :: {:ok, session} | {:error, Ecto.Changeset.t()}
end
