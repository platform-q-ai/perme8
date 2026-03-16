defmodule Agents.Sessions.Domain.Policies.SessionStateMachinePolicy do
  @moduledoc """
  Pure domain policy for session lifecycle state transitions.

  Enforces valid transitions between session statuses:
  active -> paused, paused -> active, active -> completed,
  active -> failed, paused -> failed.
  """

  @valid_transitions MapSet.new([
                       {:active, :paused},
                       {:paused, :active},
                       {:active, :completed},
                       {:active, :failed},
                       {:paused, :failed}
                     ])

  @doc "Returns true if the transition is valid."
  def can_transition?(current_status, target_status)
      when is_atom(current_status) and is_atom(target_status) do
    MapSet.member?(@valid_transitions, {current_status, target_status})
  end

  def can_transition?(current_status, target_status)
      when is_binary(current_status) and is_binary(target_status) do
    can_transition?(
      String.to_existing_atom(current_status),
      String.to_existing_atom(target_status)
    )
  end

  @doc "Attempts a transition, returning {:ok, new_status} or {:error, :invalid_transition}."
  def transition(current_status, target_status) do
    if can_transition?(current_status, target_status) do
      {:ok, target_status}
    else
      {:error, :invalid_transition}
    end
  end

  def can_pause?(:active), do: true
  def can_pause?("active"), do: true
  def can_pause?(_), do: false

  def can_resume?(:paused), do: true
  def can_resume?("paused"), do: true
  def can_resume?(_), do: false

  def can_complete?(:active), do: true
  def can_complete?("active"), do: true
  def can_complete?(_), do: false

  def can_fail?(:active), do: true
  def can_fail?("active"), do: true
  def can_fail?(:paused), do: true
  def can_fail?("paused"), do: true
  def can_fail?(_), do: false
end
