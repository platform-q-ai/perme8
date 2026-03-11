defmodule Agents.Sessions.Domain.Events.SessionDiffProduced do
  @moduledoc """
  Domain event emitted when the session produces a diff summary.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      diff_summary: nil
    ],
    required: [:task_id]
end
