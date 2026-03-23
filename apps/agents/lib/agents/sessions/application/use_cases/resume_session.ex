defmodule Agents.Sessions.Application.UseCases.ResumeSession do
  @moduledoc """
  Use case for resuming a paused session.

  Sets the session status to active, records the resume timestamp,
  creates a new task of type "resume", and stores the resume instruction
  as an interaction record.
  Delegates session fetch and state-machine validation to `SessionTransition`.
  """

  alias Agents.Sessions.Application.SessionTransition
  alias Agents.Sessions.Domain.Events.SessionResumed

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository
  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_interaction_repo Agents.Sessions.Infrastructure.Repositories.InteractionRepository
  @default_queue_orchestrator Agents.Sessions.Infrastructure.QueueOrchestrator
  @default_event_bus Perme8.Events.EventBus

  @spec execute(String.t(), String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, user_id, instruction, opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    interaction_repo = Keyword.get(opts, :interaction_repo, @default_interaction_repo)
    queue_orchestrator = Keyword.get(opts, :queue_orchestrator, @default_queue_orchestrator)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    SessionTransition.with_user_session_transition(
      session_id,
      user_id,
      "active",
      fn session ->
        with {:ok, updated_session} <-
               session_repo.update_session(session, %{
                 status: "active",
                 resumed_at: DateTime.utc_now(),
                 last_activity_at: DateTime.utc_now()
               }),
             {:ok, _task} <-
               task_repo.create_task(%{
                 instruction: instruction,
                 user_id: user_id,
                 session_ref_id: session_id,
                 status: "queued",
                 queued_at: DateTime.utc_now()
               }) do
          # Store instruction as interaction record (best-effort, don't fail resume)
          _ =
            interaction_repo.create_interaction(%{
              session_id: session_id,
              type: "instruction",
              direction: "inbound",
              payload: %{text: instruction}
            })

          _ = maybe_notify_session_activity(queue_orchestrator, user_id, session_id)

          _ =
            event_bus.emit(
              SessionResumed.new(%{
                aggregate_id: session_id,
                actor_id: user_id,
                session_id: session_id,
                user_id: user_id,
                resumed_at: DateTime.utc_now()
              })
            )

          {:ok, updated_session}
        end
      end,
      opts
    )
  end

  defp maybe_notify_session_activity(queue_orchestrator, user_id, session_id) do
    queue_orchestrator.notify_session_activity(user_id, session_id)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end
end
