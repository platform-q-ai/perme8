defmodule Agents.Sessions.Application.UseCases.PauseSession do
  @moduledoc """
  Use case for pausing an active session.

  Sets the session status to paused, records the pause timestamp,
  and updates the container status to stopped.
  """

  alias Agents.Sessions.Application.SessionTransition
  alias Agents.Sessions.Domain.Events.SessionPaused

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus

  @spec execute(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, user_id, opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    SessionTransition.with_user_session_transition(
      session_id,
      user_id,
      "paused",
      fn session ->
        with {:ok, updated} <- do_pause(session, session_repo) do
          emit_paused(session_id, user_id, event_bus)
          {:ok, updated}
        end
      end,
      opts
    )
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
