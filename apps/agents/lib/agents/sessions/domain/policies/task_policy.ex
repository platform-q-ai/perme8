defmodule Agents.Sessions.Domain.Policies.TaskPolicy do
  @moduledoc """
  Pure business rules for task status management.

  Contains no I/O, no infrastructure dependencies.
  All functions are pure and deterministic.
  """

  @valid_statuses ["pending", "starting", "running", "completed", "failed", "cancelled"]
  @cancellable_statuses ["pending", "starting", "running"]

  @doc """
  Returns true if the given status is a valid task status.
  """
  def valid_status?(status) when status in @valid_statuses, do: true
  def valid_status?(_), do: false

  @doc """
  Returns true if the task can be cancelled from the given status.
  """
  def can_cancel?(status) when status in @cancellable_statuses, do: true
  def can_cancel?(_), do: false

  @doc """
  Returns true if transitioning from `old_status` to `new_status` is allowed.
  """
  def valid_status_transition?("pending", "starting"), do: true
  def valid_status_transition?("pending", "cancelled"), do: true
  def valid_status_transition?("starting", "running"), do: true
  def valid_status_transition?("starting", "failed"), do: true
  def valid_status_transition?("starting", "cancelled"), do: true
  def valid_status_transition?("running", "completed"), do: true
  def valid_status_transition?("running", "failed"), do: true
  def valid_status_transition?("running", "cancelled"), do: true
  def valid_status_transition?(_, _), do: false
end
