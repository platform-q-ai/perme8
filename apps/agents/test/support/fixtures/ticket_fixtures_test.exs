defmodule Agents.Test.TicketFixturesTest do
  use ExUnit.Case, async: true

  alias Agents.Test.TicketFixtures

  test "issue_map/1 returns default issue fields" do
    issue = TicketFixtures.issue_map()

    assert issue.number == 1
    assert issue.title == "Test Issue"
    assert issue.state == "open"
    assert issue.labels == ["enhancement"]
  end

  test "comment_map/1 returns default comment fields" do
    comment = TicketFixtures.comment_map()

    assert comment.id == 1
    assert comment.body == "Test comment"
    assert comment.url =~ "issuecomment"
  end

  test "api_key_struct/0 returns MCP ticket scopes" do
    api_key = TicketFixtures.api_key_struct()

    assert api_key.id == "test-api-key-id"
    assert "mcp:ticket.read" in api_key.scopes
    assert "mcp:ticket.remove_sub_issue" in api_key.scopes
  end
end
