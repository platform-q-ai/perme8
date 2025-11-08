defmodule Jarga.Documents.UseCases.LoadSession do
  @moduledoc """
  Loads a chat session with its messages and relationships.

  This use case retrieves a chat session from the database along with
  all its messages (ordered chronologically) and related entities.

  ## Responsibilities
  - Load session by ID
  - Preload messages ordered by insertion time
  - Preload user, workspace, and project relationships
  - Return error if session not found

  ## Examples

      iex> LoadSession.execute(session_id)
      {:ok, %ChatSession{messages: [%ChatMessage{}, ...]}}

      iex> LoadSession.execute(invalid_id)
      {:error, :not_found}
  """

  import Ecto.Query

  alias Jarga.Repo
  alias Jarga.Documents.ChatSession

  @doc """
  Loads a chat session with all its data.

  ## Parameters
    - session_id: The ID of the session to load

  Returns `{:ok, session}` with preloaded messages and relationships,
  or `{:error, :not_found}` if the session doesn't exist.
  """
  def execute(session_id) do
    query =
      from s in ChatSession,
        where: s.id == ^session_id,
        preload: [
          :user,
          :workspace,
          :project,
          messages: ^messages_query()
        ]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  defp messages_query do
    from m in Jarga.Documents.ChatMessage,
      order_by: [asc: m.inserted_at]
  end
end
