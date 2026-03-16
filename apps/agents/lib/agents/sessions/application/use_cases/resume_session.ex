defmodule Agents.Sessions.Application.UseCases.ResumeSession do
  @moduledoc """
  Use case for resuming a paused session.

  Sets the session status to active, records the resume timestamp,
  creates a new task of type "resume", and stores the resume instruction
  as an interaction record.
  """

  alias Agents.Sessions.Domain.Events.SessionResumed
  alias Agents.Sessions.Domain.Policies.SessionStateMachinePolicy

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository
  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_interaction_repo Agents.Sessions.Infrastructure.Repositories.InteractionRepository
  @default_event_bus Perme8.Events.EventBus

  @spec execute(String.t(), String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, user_id, instruction, opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    interaction_repo = Keyword.get(opts, :interaction_repo, @default_interaction_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    case session_repo.get_session_for_user(session_id, user_id) do
      nil ->
        {:error, :not_found}

      session ->
        if SessionStateMachinePolicy.can_resume?(session.status) do
          with {:ok, updated_session} <-
                 session_repo.update_session(session, %{
                   status: "active",
                   resumed_at: DateTime.utc_now()
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
        else
          {:error, :invalid_transition}
        end
    end
  end
end
