defmodule Agents.Sessions.Domain.Policies.SessionLifecyclePolicy do
  @moduledoc """
  Pure lifecycle-state derivation and transition rules for session tasks.
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
                       {:running, :awaiting_feedback},
                       {:awaiting_feedback, :queued_cold},
                       {:awaiting_feedback, :queued_warm}
                     ])

  @spec derive(map() | nil) :: atom()
  def derive(nil), do: :idle

  def derive(task) when is_map(task) do
    status = value(task, :status)
    container_id = value(task, :container_id)
    container_port = value(task, :container_port)

    case status do
      nil -> :idle
      "queued" -> if(real_container?(container_id), do: :queued_warm, else: :queued_cold)
      "pending" -> derive_pending_state(container_id, container_port)
      "starting" -> :starting
      "running" -> :running
      "awaiting_feedback" -> :awaiting_feedback
      "completed" -> :completed
      "failed" -> :failed
      "cancelled" -> :cancelled
      _ -> :idle
    end
  end

  @spec can_transition?(atom(), atom()) :: boolean()
  def can_transition?(from_state, to_state),
    do: MapSet.member?(@valid_transitions, {from_state, to_state})

  @spec active?(atom()) :: boolean()
  def active?(state), do: state in @active_states

  @spec terminal?(atom()) :: boolean()
  def terminal?(state), do: state in @terminal_states

  @spec warm?(atom()) :: boolean()
  def warm?(state), do: state in @warm_states

  @spec cold?(atom()) :: boolean()
  def cold?(state), do: state in @cold_states

  @spec can_submit_message?(atom()) :: boolean()
  def can_submit_message?(state), do: active?(state)

  defp derive_pending_state(container_id, container_port) do
    cond do
      real_container?(container_id) and is_nil(container_port) -> :warming
      true -> :pending
    end
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
