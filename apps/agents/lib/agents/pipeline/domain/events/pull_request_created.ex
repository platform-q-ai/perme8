defmodule Agents.Pipeline.Domain.Events.PullRequestCreated do
  @moduledoc "Emitted when an internal pull request is created."

  use Perme8.Events.DomainEvent,
    aggregate_type: "pull_request",
    fields: [number: nil, title: nil, source_branch: nil, target_branch: nil, linked_ticket: nil],
    required: [:number]
end
