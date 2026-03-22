defmodule Agents.Pipeline.Domain.Events.PullRequestUpdatedTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Events.PullRequestUpdated

  @valid_attrs %{
    aggregate_id: "pr-42",
    actor_id: "user-123",
    number: 42,
    status: "in_review",
    title: "Updated PR",
    source_branch: "feature/pr-tab",
    target_branch: "main",
    linked_ticket: 506,
    changes: %{status: "in_review"}
  }

  test "returns event and aggregate types" do
    assert PullRequestUpdated.event_type() == "pipeline.pull_request_updated"
    assert PullRequestUpdated.aggregate_type() == "pull_request"
  end

  test "new/1 builds event with changes" do
    event = PullRequestUpdated.new(@valid_attrs)

    assert event.number == 42
    assert event.status == "in_review"
    assert event.title == "Updated PR"
    assert event.changes == %{status: "in_review"}
  end

  test "new/1 raises when required fields are missing" do
    assert_raise ArgumentError, fn ->
      PullRequestUpdated.new(%{aggregate_id: "pr-42", actor_id: "user-123"})
    end
  end
end
