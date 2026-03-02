defmodule Chat.Application.Behaviours.SessionRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the session repository contract.
  """

  @type session :: struct()
  @type message :: struct()
  @type pagination_opts :: [message_limit: non_neg_integer(), before_id: Ecto.UUID.t()]

  @callback get_session_by_id(Ecto.UUID.t()) :: session | nil
  @callback get_session_by_id(Ecto.UUID.t(), pagination_opts()) :: session | nil
  @callback get_session_by_id_and_user(Ecto.UUID.t(), Ecto.UUID.t()) :: session | nil
  @callback list_user_sessions(Ecto.UUID.t(), non_neg_integer()) :: list(map())
  @callback list_user_sessions_with_preview(Ecto.UUID.t(), non_neg_integer()) :: list(map())
  @callback get_first_message_content(Ecto.UUID.t()) :: String.t() | nil
  @callback get_message_by_id_and_user(Ecto.UUID.t(), Ecto.UUID.t()) :: message | nil
  @callback load_messages(Ecto.UUID.t(), pagination_opts()) :: list(message)
  @callback create_session(map()) :: {:ok, session} | {:error, Ecto.Changeset.t()}
  @callback delete_session(session) :: {:ok, session} | {:error, Ecto.Changeset.t()}
end
