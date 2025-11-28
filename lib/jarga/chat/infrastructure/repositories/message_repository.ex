defmodule Jarga.Chat.Infrastructure.Repositories.MessageRepository do
  @moduledoc """
  Repository for chat message data access.

  This module follows Clean Architecture Infrastructure Layer principles:
  - Encapsulates all database access for messages
  - Provides testable interface (repo can be injected)
  - Abstracts Repo calls from use cases
  - Provides clear separation from business logic
  """

  alias Jarga.Repo
  alias Jarga.Chat.Infrastructure.Schemas.MessageSchema

  @doc """
  Creates a new chat message.

  ## Parameters
    - attrs: Map with the following keys:
      - chat_session_id: (required) ID of the chat session
      - role: (required) Either "user" or "assistant"
      - content: (required) Message content
      - context_chunks: (optional) Array of document chunk IDs used as context

  Returns `{:ok, message}` if successful, or `{:error, changeset}` if validation fails.

  ## Examples

      iex> create_message(%{chat_session_id: session.id, role: "user", content: "Hello"})
      {:ok, %ChatMessage{}}

      iex> create_message(%{role: "user"})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_message(map(), module()) ::
          {:ok, MessageSchema.t()} | {:error, Ecto.Changeset.t()}
  def create_message(attrs, repo \\ Repo) do
    %MessageSchema{}
    |> MessageSchema.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Deletes a chat message.

  ## Examples

      iex> delete_message(message)
      {:ok, %ChatMessage{}}

      iex> delete_message(invalid_message)
      {:error, %Ecto.Changeset{}}
  """
  @spec delete_message(MessageSchema.t(), module()) ::
          {:ok, MessageSchema.t()} | {:error, Ecto.Changeset.t()}
  def delete_message(%MessageSchema{} = message, repo \\ Repo) do
    repo.delete(message)
  end
end
