defmodule Agents.Pipeline.Domain.Events.PullRequestMerged do
  @moduledoc "Emitted when an internal pull request is merged."

  use Perme8.Events.DomainEvent,
    aggregate_type: "pull_request",
    fields: [number: nil, source_branch: nil, target_branch: nil, linked_ticket: nil],
    required: [:number]
end
