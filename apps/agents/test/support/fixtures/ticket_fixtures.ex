defmodule Agents.Test.TicketFixtures do
  @moduledoc false

  def issue_map(overrides \\ %{}) do
    Map.merge(
      %{
        number: 1,
        title: "Test Issue",
        body: "Test body",
        state: "open",
        labels: ["enhancement"],
        assignees: ["testuser"],
        url: "https://github.com/platform-q-ai/perme8/issues/1",
        comments: [],
        sub_issue_numbers: [],
        created_at: "2025-01-01T00:00:00Z"
      },
      overrides
    )
  end

  def comment_map(overrides \\ %{}) do
    Map.merge(
      %{
        id: 1,
        body: "Test comment",
        url: "https://github.com/platform-q-ai/perme8/issues/1#issuecomment-1",
        created_at: "2025-01-01T00:00:00Z"
      },
      overrides
    )
  end

  def api_key_struct do
    %{
      id: "test-api-key-id",
      scopes: [
        "mcp:ticket.read",
        "mcp:ticket.list",
        "mcp:ticket.create",
        "mcp:ticket.update",
        "mcp:ticket.close",
        "mcp:ticket.add_sub_issue",
        "mcp:ticket.remove_sub_issue",
        "mcp:ticket.add_dependency",
        "mcp:ticket.remove_dependency",
        "mcp:ticket.search_dependency_targets"
      ]
    }
  end
end
