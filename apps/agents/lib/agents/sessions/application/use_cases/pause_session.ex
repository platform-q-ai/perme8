defmodule Agents.Sessions.Application.UseCases.PauseSession do
  @moduledoc """
  Use case for pausing an active session.

  Sets the session status to paused, records the pause timestamp,
  and updates the container status to stopped.
  """

  alias Agents.Sessions.Domain.Events.SessionPaused
  alias Agents.Sessions.Domain.Policies.SessionStateMachinePolicy

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus

  @spec execute(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, user_id, opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    with {:ok, session} <- fetch_session(session_id, user_id, session_repo),
         :ok <- validate_transition(session),
         {:ok, updated} <- do_pause(session, session_repo) do
      emit_paused(session_id, user_id, event_bus)
      {:ok, updated}
    end
  end

  defp fetch_session(session_id, user_id, session_repo) do
    case session_repo.get_session_for_user(session_id, user_id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  defp validate_transition(session) do
    if SessionStateMachinePolicy.can_pause?(session.status),
      do: :ok,
      else: {:error, :invalid_transition}
  end

  defp do_pause(session, session_repo) do
    session_repo.update_session(session, %{
      status: "paused",
      paused_at: DateTime.utc_now(),
      container_status: "stopped"
    })
  end

  defp emit_paused(session_id, user_id, event_bus) do
    event_bus.emit(
      SessionPaused.new(%{
        aggregate_id: session_id,
        actor_id: user_id,
        session_id: session_id,
        user_id: user_id,
        paused_at: DateTime.utc_now()
      })
    )
  end
end
