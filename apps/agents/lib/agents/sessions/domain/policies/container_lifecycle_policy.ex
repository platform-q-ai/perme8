defmodule Agents.Sessions.Domain.Policies.ContainerLifecyclePolicy do
  @moduledoc """
  Pure domain policy for container status transitions.

  Defines valid container status values, allowed transitions, and
  compensation actions for the saga pattern.
  """

  @valid_statuses [:pending, :starting, :running, :stopped, :removed]

  @valid_transitions MapSet.new([
                       {:pending, :starting},
                       {:starting, :running},
                       {:running, :stopped},
                       {:stopped, :removed},
                       # Forced removal from any state
                       {:pending, :removed},
                       {:starting, :removed},
                       {:running, :removed},
                       {:stopped, :removed},
                       # Failure paths
                       {:starting, :stopped},
                       {:pending, :stopped}
                     ])

  @doc "Returns true if the status is valid."
  def valid_status?(status), do: status in @valid_statuses

  @doc "Returns true if the transition between statuses is allowed."
  def can_transition?(current_status, target_status),
    do: MapSet.member?(@valid_transitions, {current_status, target_status})

  @doc """
  Returns the compensation action for a failure at the given stage.

  - If container creation fails (pending -> starting failed): delete session record
  - If DB update fails after container start: stop and remove container
  """
  def compensation_action(:container_start_failed), do: :delete_session
  def compensation_action(:db_update_failed), do: :stop_and_remove_container
  def compensation_action(_), do: :none

  def valid_statuses, do: @valid_statuses
end
