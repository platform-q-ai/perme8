defmodule Jarga.Chat.Infrastructure.Repositories.SessionRepository do
  @moduledoc """
  Repository for chat session data access.

  This module follows Clean Architecture Infrastructure Layer principles:
  - Encapsulates all database access for sessions
  - Uses Query objects for composable queries
  - Provides testable interface (repo can be injected)
  - Abstracts Repo calls from use cases

  ## Design
  According to ARCHITECTURE.md lines 450-487, repositories:
  - Handle data access and abstract database queries
  - Use Query objects for building queries
  - Allow dependency injection for testing
  - Provide clear separation from business logic
  """

  @behaviour Jarga.Chat.Application.Behaviours.SessionRepositoryBehaviour

  alias Identity.Repo, as: Repo
  alias Jarga.Chat.Infrastructure.Queries.Queries

  @doc """
  Loads a session by ID with preloaded relationships.

  Returns the session struct or nil if not found.
  """
  def get_session_by_id(session_id, repo \\ Repo) do
    session_id
    |> Queries.by_id()
    |> Queries.with_preloads()
    |> repo.one()
  end

  @doc """
  Lists sessions for a user with message counts.

  Returns a list of session maps with aggregated data.
  """
  def list_user_sessions(user_id, limit, repo \\ Repo) do
    user_id
    |> Queries.for_user()
    |> Queries.ordered_by_recent()
    |> Queries.with_message_count()
    |> Queries.limit_results(limit)
    |> repo.all()
  end

  @doc """
  Gets the first message content for a session (for preview).

  Returns the message content string or nil if no messages.
  """
  def get_first_message_content(session_id, repo \\ Repo) do
    session_id
    |> Queries.first_message_content()
    |> repo.one()
  end

  @doc """
  Finds a session by ID and user ID (for authorization).

  Returns the session struct or nil if not found or unauthorized.
  """
  def get_session_by_id_and_user(session_id, user_id, repo \\ Repo) do
    session_id
    |> Queries.by_id_and_user(user_id)
    |> repo.one()
  end

  @doc """
  Finds a message by ID with user ownership verification through session.

  Returns the message struct or nil if not found or unauthorized.
  """
  @impl true
  def get_message_by_id_and_user(message_id, user_id, repo \\ Repo) do
    message_id
    |> Queries.message_by_id_and_user(user_id)
    |> repo.one()
  end

  @doc """
  Creates a new chat session.

  ## Parameters
    - attrs: Map with the following keys:
      - user_id: (required) ID of the user creating the session
      - workspace_id: (optional) ID of the workspace
      - project_id: (optional) ID of the project
      - title: (optional) Title of the session

  Returns `{:ok, session}` if successful, or `{:error, changeset}` if validation fails.
  """
  @impl true
  def create_session(attrs, repo \\ Repo) do
    alias Jarga.Chat.Infrastructure.Schemas.SessionSchema

    %SessionSchema{}
    |> SessionSchema.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Deletes a chat session.

  Messages are automatically deleted via database cascade.

  ## Examples

      iex> delete_session(session)
      {:ok, %ChatSession{}}
  """
  def delete_session(session, repo \\ Repo) do
    repo.delete(session)
  end
end
