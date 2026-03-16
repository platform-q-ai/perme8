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
  def can_transition?(from, to) when is_atom(from) and is_atom(to) do
    MapSet.member?(@valid_transitions, {from, to})
  end

  def can_transition?(from, to) when is_binary(from) and is_binary(to) do
    can_transition?(String.to_existing_atom(from), String.to_existing_atom(to))
  end

  @doc "Attempts a transition, returning {:ok, new_status} or {:error, :invalid_transition}."
  def transition(from, to) do
    if can_transition?(from, to) do
      {:ok, to}
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
