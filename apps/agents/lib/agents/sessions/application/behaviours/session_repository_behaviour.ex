defmodule Agents.Sessions.Application.Behaviours.SessionRepositoryBehaviour do
  @moduledoc """
  Behaviour for session repository operations.

  Defines the contract for session persistence, enabling dependency injection
  and testability via mocks. All callbacks return `SessionRecord` domain
  entities, keeping the Application layer free of Infrastructure types.
  """

  alias Agents.Sessions.Domain.Entities.SessionRecord

  @type session_record :: SessionRecord.t()

  @callback create_session(map()) :: {:ok, session_record()} | {:error, Ecto.Changeset.t()}
  @callback get_session(String.t()) :: session_record() | nil
  @callback get_session_for_user(String.t(), String.t()) :: session_record() | nil
  @callback update_session(session_record(), map()) ::
              {:ok, session_record()} | {:error, Ecto.Changeset.t()}
  @callback list_sessions_for_user(String.t(), keyword()) :: [session_record()]
  @callback delete_session(session_record()) :: {:ok, session_record()} | {:error, term()}
  @callback get_session_by_container_id(String.t()) :: session_record() | nil
end
