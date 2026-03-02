defmodule Chat.Infrastructure.Repositories.SessionRepository do
  @moduledoc """
  Repository for chat session data access.
  """

  @behaviour Chat.Application.Behaviours.SessionRepositoryBehaviour

  alias Chat.Infrastructure.Queries.Queries
  alias Chat.Repo

  @impl true
  def get_session_by_id(session_id, repo_or_opts \\ Repo)

  def get_session_by_id(session_id, opts) when is_list(opts) do
    message_limit = Keyword.get(opts, :message_limit, 50)

    session_id
    |> Queries.by_id()
    |> Queries.with_paginated_messages(message_limit)
    |> Repo.one()
    |> maybe_sort_messages()
  end

  def get_session_by_id(session_id, repo) do
    session_id
    |> Queries.by_id()
    |> Queries.with_preloads()
    |> repo.one()
  end

  @impl true
  def list_user_sessions(user_id, limit, repo \\ Repo) do
    user_id
    |> Queries.for_user()
    |> Queries.ordered_by_recent()
    |> Queries.with_message_count()
    |> Queries.limit_results(limit)
    |> repo.all()
  end

  @impl true
  def list_user_sessions_with_preview(user_id, limit, repo \\ Repo) do
    user_id
    |> Queries.for_user()
    |> Queries.ordered_by_recent()
    |> Queries.with_message_count_and_preview()
    |> Queries.limit_results(limit)
    |> repo.all()
  end

  @impl true
  def get_first_message_content(session_id, repo \\ Repo) do
    session_id
    |> Queries.first_message_content()
    |> repo.one()
  end

  @impl true
  def get_session_by_id_and_user(session_id, user_id, repo \\ Repo) do
    session_id
    |> Queries.by_id_and_user(user_id)
    |> repo.one()
  end

  @impl true
  def get_message_by_id_and_user(message_id, user_id, repo \\ Repo) do
    message_id
    |> Queries.message_by_id_and_user(user_id)
    |> repo.one()
  end

  @impl true
  def load_messages(session_id, opts, repo \\ Repo) do
    limit = Keyword.get(opts, :message_limit, 50)
    before_id = Keyword.get(opts, :before_id)

    messages =
      session_id
      |> Queries.messages_before(before_id, limit)
      |> repo.all()

    # Return in ascending order (oldest first)
    Enum.sort_by(messages, & &1.inserted_at, DateTime)
  end

  @impl true
  def create_session(attrs, repo \\ Repo) do
    alias Chat.Infrastructure.Schemas.SessionSchema

    %SessionSchema{}
    |> SessionSchema.changeset(attrs)
    |> repo.insert()
  end

  @impl true
  def delete_session(session, repo \\ Repo) do
    repo.delete(session)
  end

  # Preloaded messages from with_paginated_messages come in desc order;
  # sort them ascending for display.
  defp maybe_sort_messages(nil), do: nil

  defp maybe_sort_messages(session) do
    sorted = Enum.sort_by(session.messages, & &1.inserted_at, DateTime)
    %{session | messages: sorted}
  end
end
