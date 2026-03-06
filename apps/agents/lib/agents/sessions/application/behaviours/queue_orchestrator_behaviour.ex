defmodule Agents.Sessions.Application.Behaviours.QueueOrchestratorBehaviour do
  @moduledoc """
  Behaviour defining the contract for queue orchestration.

  The orchestrator manages per-user queue state, handles task lifecycle
  transitions, and produces canonical QueueSnapshot structs.
  """

  alias Agents.Sessions.Domain.Entities.QueueSnapshot

  @callback get_snapshot(String.t()) :: QueueSnapshot.t()
  @callback notify_task_queued(String.t(), String.t()) :: :ok
  @callback notify_task_completed(String.t(), String.t()) :: :ok
  @callback notify_task_failed(String.t(), String.t()) :: :ok
  @callback notify_task_cancelled(String.t(), String.t()) :: :ok
  @callback notify_question_asked(String.t(), String.t()) :: :ok
  @callback notify_feedback_provided(String.t(), String.t()) :: :ok
  @callback set_concurrency_limit(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  @callback set_warm_cache_limit(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  @callback check_concurrency(String.t()) :: :ok | :at_limit
end
