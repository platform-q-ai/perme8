defmodule AgentsWeb.DashboardLive.SessionStateMachine do
  @moduledoc """
  Explicit state machine for session lifecycle.

  Centralizes all session state predicates and submission routing decisions.
  Pure functions with no side effects — easily unit-testable.

  ## States

  - `:idle` — no task selected or task has nil status
  - `:pending` — task created, waiting to start
  - `:starting` — task container is spinning up
  - `:running` — task is actively executing
  - `:queued` — task is waiting in the queue for a slot
  - `:awaiting_feedback` — task is paused, waiting for user input (e.g., a question)
  - `:completed` — task finished successfully
  - `:failed` — task terminated with an error
  - `:cancelled` — task was cancelled by the user
  - `:unknown` — unrecognized status string
  """

  @type state ::
          :idle
          | :queued_cold
          | :queued_warm
          | :warming
          | :pending
          | :starting
          | :running
          | :queued
          | :awaiting_feedback
          | :completed
          | :failed
          | :cancelled
          | :unknown

  @type submission_route :: :follow_up | :new_or_resume | :blocked

  @status_to_state %{
    "pending" => :pending,
    "queued_cold" => :queued_cold,
    "queued_warm" => :queued_warm,
    "warming" => :warming,
    "starting" => :starting,
    "running" => :running,
    "queued" => :queued,
    "awaiting_feedback" => :awaiting_feedback,
    "completed" => :completed,
    "failed" => :failed,
    "cancelled" => :cancelled
  }

  @running_states [:warming, :pending, :starting, :running]
  @active_states [
    :queued_cold,
    :queued_warm,
    :warming,
    :pending,
    :starting,
    :running,
    :queued,
    :awaiting_feedback
  ]
  @terminal_states [:completed, :failed, :cancelled]

  # ---------- State derivation ----------

  @doc """
  Derives the session state from a task struct (or nil).

  Accepts any map with a `:status` field, or nil.
  """
  @spec state_from_task(map() | nil) :: state()
  def state_from_task(nil), do: :idle
  def state_from_task(%{status: nil}), do: :idle

  def state_from_task(%{lifecycle_state: lifecycle_state} = task)
      when is_binary(lifecycle_state) do
    lifecycle = Map.get(@status_to_state, lifecycle_state, :unknown)
    status_state = status_state_from_task(task)

    cond do
      lifecycle == :idle and status_state != :unknown ->
        status_state

      status_state in @terminal_states and lifecycle not in @terminal_states ->
        status_state

      true ->
        lifecycle
    end
  end

  def state_from_task(%{status: status}) when is_binary(status) do
    Map.get(@status_to_state, status, :unknown)
  end

  defp status_state_from_task(%{status: status}) when is_binary(status) do
    Map.get(@status_to_state, status, :unknown)
  end

  defp status_state_from_task(_), do: :unknown

  # ---------- State predicates ----------

  @doc "Returns true if the task is currently running (pending, starting, or running)."
  @spec task_running?(state()) :: boolean()
  def task_running?(state), do: state in @running_states

  @doc "Returns true if the session is in the warming state."
  @spec warming?(state()) :: boolean()
  def warming?(state), do: state == :warming

  @doc "Returns true if the session is queued without a warm container."
  @spec queued_cold?(state()) :: boolean()
  def queued_cold?(state), do: state == :queued_cold

  @doc "Returns true if the session is queued with a warm container."
  @spec queued_warm?(state()) :: boolean()
  def queued_warm?(state), do: state == :queued_warm

  @doc "Returns true if the task is in an active (non-terminal, non-idle) state."
  @spec active?(state()) :: boolean()
  def active?(state), do: state in @active_states

  @doc "Returns true if the task is in a terminal state."
  @spec terminal?(state()) :: boolean()
  def terminal?(state), do: state in @terminal_states

  @doc """
  Returns true if a message can be submitted to the task in this state.

  Messages can be sent to any active task. For `:queued` and `:awaiting_feedback`
  states, the message is queued as a follow-up rather than sent immediately.
  """
  @spec can_submit_message?(state()) :: boolean()
  def can_submit_message?(state), do: state in @active_states

  # ---------- Submission routing ----------

  @doc """
  Determines how a user message submission should be routed.

  - `:follow_up` — send as a follow-up message to the active task
  - `:new_or_resume` — start a new task or resume a completed one
  - `:blocked` — submission cannot proceed (unknown state)
  """
  @spec submission_route(state()) :: submission_route()
  def submission_route(state) when state in @active_states, do: :follow_up
  def submission_route(state) when state in @terminal_states, do: :new_or_resume
  def submission_route(:idle), do: :new_or_resume
  def submission_route(:unknown), do: :blocked

  @doc "Returns a human-readable display name for the session state."
  @spec display_name(state()) :: String.t()
  def display_name(state), do: Agents.Sessions.session_display_name(state)

  # ---------- Task-level convenience ----------

  @doc """
  Returns true if a task struct is resumable.

  A task is resumable when it is in a terminal state and has both
  a `container_id` and `session_id` present.
  """
  @spec resumable?(map() | nil) :: boolean()
  def resumable?(nil), do: false

  def resumable?(%{status: _, container_id: cid, session_id: sid} = task) do
    terminal?(state_from_task(task)) and not is_nil(cid) and not is_nil(sid)
  end

  def resumable?(_), do: false

  # ---------- Queued message helpers ----------

  @default_stale_seconds 120

  @doc """
  Returns true if a queued message is stale (pending beyond the TTL).

  Only considers messages with status `"pending"` — messages that have
  already been resolved (`"rolled_back"`, `"timed_out"`) are not stale.
  """
  @spec stale_queued_message?(map(), non_neg_integer()) :: boolean()
  def stale_queued_message?(msg, ttl_seconds \\ @default_stale_seconds)

  def stale_queued_message?(%{status: "pending", queued_at: nil}, _ttl_seconds), do: true

  def stale_queued_message?(%{status: "pending", queued_at: queued_at}, ttl_seconds) do
    DateTime.diff(DateTime.utc_now(), queued_at, :second) > ttl_seconds
  end

  def stale_queued_message?(_msg, _ttl_seconds), do: false

  @doc """
  Marks a queued message's status by matching on correlation_key or id.
  """
  @spec mark_queued_message_status([map()], String.t(), String.t()) :: [map()]
  def mark_queued_message_status(messages, correlation_key, status) do
    Enum.map(messages, fn msg ->
      key = msg[:correlation_key] || msg[:id]
      if key == correlation_key, do: Map.put(msg, :status, status), else: msg
    end)
  end
end
