defmodule Jarga.Documents.UseCases.DeleteSession do
  @moduledoc """
  Deletes a chat session and all its messages.

  Only allows users to delete their own sessions (authorization check).

  ## Examples

      iex> DeleteSession.execute(session_id, user_id)
      {:ok, %ChatSession{}}

      iex> DeleteSession.execute(invalid_id, user_id)
      {:error, :not_found}
  """

  import Ecto.Query

  alias Jarga.Repo
  alias Jarga.Documents.ChatSession

  @doc """
  Deletes a chat session.

  ## Parameters
    - session_id: ID of the session to delete
    - user_id: ID of the user (for authorization)

  Returns `{:ok, deleted_session}` if successful,
  or `{:error, :not_found}` if session doesn't exist or user doesn't own it.

  Messages are automatically deleted via database cascade.
  """
  def execute(session_id, user_id) do
    query =
      from s in ChatSession,
        where: s.id == ^session_id and s.user_id == ^user_id

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      session ->
        case Repo.delete(session) do
          {:ok, deleted_session} -> {:ok, deleted_session}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end
end
