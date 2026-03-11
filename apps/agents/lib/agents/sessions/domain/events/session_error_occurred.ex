defmodule Agents.Sessions.Domain.Events.SessionErrorOccurred do
  @moduledoc """
  Domain event emitted when a session encounters an SDK-reported error.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      error_message: nil,
      error_category: nil,
      recoverable: false
    ],
    required: [:task_id, :error_message]
end
