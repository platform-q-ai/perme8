defmodule Agents.Sessions.Domain.Events.QueueSnapshotUpdated do
  @moduledoc """
  Domain event emitted when a user's queue snapshot is refreshed.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "queue",
    fields: [user_id: nil, snapshot: nil],
    required: [:user_id]
end
