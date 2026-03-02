defmodule Agents.Sessions.Domain.Policies.TaskPolicy do
  @moduledoc """
  Pure business rules for task status management.

  Contains no I/O, no infrastructure dependencies.
  All functions are pure and deterministic.
  """

  @valid_statuses [
    "pending",
    "starting",
    "running",
    "completed",
    "failed",
    "cancelled",
    "queued",
    "awaiting_feedback"
  ]
  @cancellable_statuses ["pending", "starting", "running", "queued", "awaiting_feedback"]
  @deletable_statuses ["completed", "failed", "cancelled"]

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
  Returns true if the task can be deleted from the given status.
  Only terminal statuses (completed, failed, cancelled) are deletable.
  """
  def can_delete?(status) when status in @deletable_statuses, do: true
  def can_delete?(_), do: false
end
