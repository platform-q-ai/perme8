defmodule Agents.Sessions.Application.Behaviours.SessionRepositoryBehaviour do
  @moduledoc """
  Behaviour for session repository operations.

  Defines the contract for session persistence, enabling dependency injection
  and testability via mocks.
  """

  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema

  @callback create_session(map()) :: {:ok, SessionSchema.t()} | {:error, Ecto.Changeset.t()}
  @callback get_session(String.t()) :: SessionSchema.t() | nil
  @callback get_session_for_user(String.t(), String.t()) :: SessionSchema.t() | nil
  @callback update_session(SessionSchema.t(), map()) ::
              {:ok, SessionSchema.t()} | {:error, Ecto.Changeset.t()}
  @callback list_sessions_for_user(String.t(), keyword()) :: [SessionSchema.t()]
  @callback delete_session(SessionSchema.t()) :: {:ok, SessionSchema.t()} | {:error, term()}
  @callback get_session_by_container_id(String.t()) :: SessionSchema.t() | nil
end
