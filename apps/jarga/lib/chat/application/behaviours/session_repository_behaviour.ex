defmodule Jarga.Chat.Application.Behaviours.SessionRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the session repository contract.
  """

  @type session :: struct()
  @type message :: struct()
  @type repo :: module()

  @callback get_message_by_id_and_user(Ecto.UUID.t(), Ecto.UUID.t(), repo) :: message | nil
  @callback create_session(map(), repo) :: {:ok, session} | {:error, Ecto.Changeset.t()}
  @callback list_all_sessions(non_neg_integer(), repo) :: [map()]
  @callback get_first_message_contents([Ecto.UUID.t()], repo) :: %{
              Ecto.UUID.t() => String.t() | nil
            }
end
