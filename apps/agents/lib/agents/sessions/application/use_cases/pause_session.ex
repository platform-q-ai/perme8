defmodule Agents.Sessions.Application.UseCases.PauseSession do
  @moduledoc """
  Use case for pausing an active session.

  Sets the session status to paused, records the pause timestamp,
  and updates the container status to stopped.
  """

  alias Agents.Sessions.Domain.Policies.SessionStateMachinePolicy

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository

  @spec execute(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, user_id, opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)

    case session_repo.get_session_for_user(session_id, user_id) do
      nil ->
        {:error, :not_found}

      session ->
        if SessionStateMachinePolicy.can_pause?(session.status) do
          session_repo.update_session(session, %{
            status: "paused",
            paused_at: DateTime.utc_now(),
            container_status: "stopped"
          })
        else
          {:error, :invalid_transition}
        end
    end
  end
end
