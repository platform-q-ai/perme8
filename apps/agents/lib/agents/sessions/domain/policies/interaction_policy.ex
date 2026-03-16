defmodule Agents.Sessions.Domain.Policies.InteractionPolicy do
  @moduledoc """
  Pure domain policy for interaction validation rules.

  Determines whether interactions can be created, modified, or answered
  based on their type and status.
  """

  alias Agents.Sessions.Domain.Entities.Interaction

  @valid_types Interaction.valid_types()
  @valid_directions Interaction.valid_directions()
  @valid_statuses Interaction.valid_statuses()

  @immutable_statuses [:delivered, :expired, :timed_out]

  @doc "Returns true if the type is valid."
  def valid_type?(type), do: type in @valid_types

  @doc "Returns true if the direction is valid."
  def valid_direction?(direction), do: direction in @valid_directions

  @doc "Returns true if the status is valid."
  def valid_status?(status), do: status in @valid_statuses

  @doc """
  Returns true if the interaction can be modified.

  Interactions in immutable states (delivered, expired, timed_out) cannot
  be modified to preserve audit trail integrity.
  """
  def can_modify?(%Interaction{status: status}), do: status not in @immutable_statuses
  def can_modify?(_), do: false

  @doc """
  Returns true if a question interaction can be answered.

  Only pending questions can be answered.
  """
  def can_answer?(%Interaction{type: :question, status: :pending}), do: true
  def can_answer?(_), do: false
end
