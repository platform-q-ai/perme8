defmodule Agents.Sessions.Domain.Policies.SessionLifecyclePolicy do
  @moduledoc """
  Pure lifecycle-state derivation and transition rules for session tasks.

  Includes queue-driven transitions and SDK-event-driven transitions such as
  `awaiting_feedback -> running|failed|cancelled`, `running -> idle`, and
  `idle -> running|completed|failed|cancelled`.
  """

  @active_states [
    :queued_cold,
    :queued_warm,
    :warming,
    :pending,
    :starting,
    :running,
    :awaiting_feedback
  ]
  @terminal_states [:completed, :failed, :cancelled]
  @warm_states [:queued_warm, :warming, :running, :starting]
  @cold_states [:queued_cold, :idle]

  @valid_transitions MapSet.new([
                       {:idle, :queued_cold},
                       {:idle, :queued_warm},
                       {:idle, :running},
                       {:idle, :completed},
                       {:idle, :failed},
                       {:idle, :cancelled},
                       {:queued_cold, :warming},
                       {:queued_cold, :pending},
                       {:queued_cold, :cancelled},
                       {:queued_warm, :pending},
                       {:queued_warm, :starting},
                       {:queued_warm, :cancelled},
                       {:warming, :pending},
                       {:warming, :failed},
                       {:warming, :cancelled},
                       {:pending, :starting},
                       {:pending, :cancelled},
                       {:starting, :running},
                       {:starting, :cancelled},
                       {:running, :completed},
                       {:running, :failed},
                       {:running, :cancelled},
                       {:running, :idle},
                       {:running, :awaiting_feedback},
                       {:awaiting_feedback, :running},
                       {:awaiting_feedback, :failed},
                       {:awaiting_feedback, :cancelled},
                       {:awaiting_feedback, :queued_cold},
                       {:awaiting_feedback, :queued_warm}
                     ])

  @doc "Derives a lifecycle state atom from a task map (or nil)."
  @spec derive(map() | nil) :: atom()
  def derive(nil), do: :idle

  def derive(task) when is_map(task) do
    status = value(task, :status)

    derive_from_status(status, task)
  end

  defp derive_from_status(nil, _task), do: :idle
  defp derive_from_status("queued", task), do: derive_queued_state(task)
  defp derive_from_status("pending", task), do: derive_pending_state(task)
  defp derive_from_status("starting", _task), do: :starting
  defp derive_from_status("running", _task), do: :running
  defp derive_from_status("awaiting_feedback", _task), do: :awaiting_feedback
  defp derive_from_status("completed", _task), do: :completed
  defp derive_from_status("failed", _task), do: :failed
  defp derive_from_status("cancelled", _task), do: :cancelled
  defp derive_from_status(_unknown, _task), do: :idle

  @doc "Returns true if a transition from `from_state` to `to_state` is valid."
  @spec can_transition?(atom(), atom()) :: boolean()
  def can_transition?(from_state, to_state),
    do: MapSet.member?(@valid_transitions, {from_state, to_state})

  @doc "Returns true if the state is an active (non-terminal, non-idle) state."
  @spec active?(atom()) :: boolean()
  def active?(state), do: state in @active_states

  @doc "Returns true if the state is a terminal state."
  @spec terminal?(atom()) :: boolean()
  def terminal?(state), do: state in @terminal_states

  @doc "Returns true if the state represents a warm container."
  @spec warm?(atom()) :: boolean()
  def warm?(state), do: state in @warm_states

  @doc "Returns true if the state represents a cold (no container) state."
  @spec cold?(atom()) :: boolean()
  def cold?(state), do: state in @cold_states

  @doc "Returns true if a message can be submitted in the given state."
  @spec can_submit_message?(atom()) :: boolean()
  def can_submit_message?(state), do: active?(state)

  defp derive_queued_state(task) do
    container_id = value(task, :container_id)

    if real_container?(container_id), do: :queued_warm, else: :queued_cold
  end

  defp derive_pending_state(task) do
    container_id = value(task, :container_id)
    container_port = value(task, :container_port)

    if real_container?(container_id) and is_nil(container_port), do: :warming, else: :pending
  end

  defp real_container?(container_id) when is_binary(container_id) do
    container_id != "" and not String.starts_with?(container_id, "task:")
  end

  defp real_container?(_), do: false

  defp value(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} -> val
      :error -> Map.get(map, Atom.to_string(key))
    end
  end
end
