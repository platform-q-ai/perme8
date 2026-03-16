defmodule Agents.Sessions.Application.Behaviours.SessionRepositoryBehaviour do
  @moduledoc """
  Behaviour for session repository operations.

  Defines the contract for session persistence, enabling dependency injection
  and testability via mocks. Uses generic struct/map types to avoid coupling
  the Application layer to Infrastructure schemas.
  """

  @type session :: struct()

  @callback create_session(map()) :: {:ok, session()} | {:error, Ecto.Changeset.t()}
  @callback get_session(String.t()) :: session() | nil
  @callback get_session_for_user(String.t(), String.t()) :: session() | nil
  @callback update_session(session(), map()) :: {:ok, session()} | {:error, Ecto.Changeset.t()}
  @callback list_sessions_for_user(String.t(), keyword()) :: [session()]
  @callback delete_session(session()) :: {:ok, session()} | {:error, term()}
  @callback get_session_by_container_id(String.t()) :: session() | nil
end
