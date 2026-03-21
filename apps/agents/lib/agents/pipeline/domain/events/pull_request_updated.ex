defmodule Agents.Pipeline.Domain.Events.PullRequestUpdated do
  @moduledoc "Emitted when an internal pull request changes."

  use Perme8.Events.DomainEvent,
    aggregate_type: "pull_request",
    fields: [number: nil, status: nil, title: nil, linked_ticket: nil, changes: %{}],
    required: [:number]
end
