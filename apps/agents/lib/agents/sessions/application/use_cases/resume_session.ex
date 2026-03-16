defmodule Agents.Sessions.Application.UseCases.ResumeSession do
  @moduledoc """
  Use case for resuming a paused session.

  Sets the session status to active, records the resume timestamp,
  creates a new task of type "resume", and stores the resume instruction
  as an interaction record.
  """

  alias Agents.Sessions.Domain.Policies.SessionStateMachinePolicy

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository
  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_interaction_repo Agents.Sessions.Infrastructure.Repositories.InteractionRepository

  @spec execute(String.t(), String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, user_id, instruction, opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    interaction_repo = Keyword.get(opts, :interaction_repo, @default_interaction_repo)

    case session_repo.get_session_for_user(session_id, user_id) do
      nil ->
        {:error, :not_found}

      session ->
        if SessionStateMachinePolicy.can_resume?(session.status) do
          # Update session status
          {:ok, updated_session} =
            session_repo.update_session(session, %{
              status: "active",
              resumed_at: DateTime.utc_now()
            })

          # Create resume task
          task_attrs = %{
            instruction: instruction,
            user_id: user_id,
            session_ref_id: session_id,
            status: "queued",
            queued_at: DateTime.utc_now()
          }

          {:ok, _task} = task_repo.create_task(task_attrs)

          # Store instruction as interaction record
          interaction_repo.create_interaction(%{
            session_id: session_id,
            type: "instruction",
            direction: "inbound",
            payload: %{text: instruction}
          })

          {:ok, updated_session}
        else
          {:error, :invalid_transition}
        end
    end
  end
end
