defmodule Jarga.Agents.UseCases.SaveMessage do
  @moduledoc """
  Saves a chat message to a session.

  This use case handles persisting messages (both user and assistant)
  to the database within a chat session.

  ## Responsibilities
  - Create and persist message records
  - Validate message content and metadata
  - Associate messages with sessions

  ## Examples

      iex> SaveMessage.execute(%{
      ...>   chat_session_id: session.id,
      ...>   role: "user",
      ...>   content: "Hello!"
      ...> })
      {:ok, %ChatMessage{}}
  """

  alias Jarga.Repo
  alias Jarga.Agents.ChatMessage

  @doc """
  Saves a new message to a chat session.

  ## Parameters
    - attrs: Map with the following keys:
      - chat_session_id: (required) ID of the chat session
      - role: (required) Either "user" or "assistant"
      - content: (required) Message content
      - context_chunks: (optional) Array of document chunk IDs used as context

  Returns `{:ok, message}` if successful, or `{:error, changeset}` if validation fails.
  """
  def execute(attrs) do
    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
  end
end
