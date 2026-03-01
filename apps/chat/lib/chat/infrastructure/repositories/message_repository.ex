defmodule Chat.Infrastructure.Repositories.MessageRepository do
  @moduledoc """
  Repository for chat message data access.
  """

  @behaviour Chat.Application.Behaviours.MessageRepositoryBehaviour

  alias Chat.Infrastructure.Schemas.MessageSchema
  alias Chat.Repo

  @impl true
  def get(id, repo \\ Repo) do
    repo.get(MessageSchema, id)
  end

  @impl true
  def create_message(attrs, repo \\ Repo) do
    %MessageSchema{}
    |> MessageSchema.changeset(attrs)
    |> repo.insert()
  end

  @impl true
  def delete_message(%MessageSchema{} = message, repo \\ Repo) do
    repo.delete(message)
  end
end
