defmodule Agents.Pipeline.Domain.Events.PullRequestCreatedTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Events.PullRequestCreated

  @valid_attrs %{
    aggregate_id: "pr-42",
    actor_id: "user-123",
    number: 42,
    title: "Internal PR",
    source_branch: "feature/pr-tab",
    target_branch: "main",
    linked_ticket: 506
  }

  test "returns event and aggregate types" do
    assert PullRequestCreated.event_type() == "pipeline.pull_request_created"
    assert PullRequestCreated.aggregate_type() == "pull_request"
  end

  test "new/1 builds event with optional fields" do
    event = PullRequestCreated.new(@valid_attrs)

    assert event.number == 42
    assert event.title == "Internal PR"
    assert event.source_branch == "feature/pr-tab"
    assert event.target_branch == "main"
    assert event.linked_ticket == 506
  end

  test "new/1 raises when required fields are missing" do
    assert_raise ArgumentError, fn ->
      PullRequestCreated.new(%{aggregate_id: "pr-42", actor_id: "user-123"})
    end
  end
end
