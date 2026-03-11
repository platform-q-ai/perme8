defmodule Agents.Infrastructure.Mcp.Tools.Ticket.HelpersTest do
  use ExUnit.Case, async: false

  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Test.TicketFixtures, as: Fixtures

  setup do
    Application.put_env(:agents, :sessions,
      github_token: "token-123",
      github_org: "platform-q-ai",
      github_repo: "perme8"
    )

    on_exit(fn ->
      Application.delete_env(:agents, :sessions)
      Application.delete_env(:agents, :github_ticket_client)
    end)

    :ok
  end

  describe "client_opts/0" do
    test "returns token, org, and repo from TicketsConfig" do
      assert Helpers.client_opts() == [token: "token-123", org: "platform-q-ai", repo: "perme8"]
    end
  end

  describe "github_client/0" do
    test "returns configured override module" do
      Application.put_env(:agents, :github_ticket_client, Agents.Mocks.GithubTicketClientMock)

      assert Helpers.github_client() == Agents.Mocks.GithubTicketClientMock
    end

    test "returns default github client module when no override configured" do
      Application.delete_env(:agents, :github_ticket_client)

      assert Helpers.github_client() == Agents.Tickets.Infrastructure.Clients.GithubProjectClient
    end
  end

  describe "format_issue/1" do
    test "formats full issue details as markdown" do
      issue =
        Fixtures.issue_map(%{
          number: 77,
          title: "MCP ticket helpers",
          labels: ["enhancement", "mcp"],
          state: "open",
          comments: [Fixtures.comment_map(%{body: "looks good"})],
          sub_issue_numbers: [11, 12]
        })

      text = Helpers.format_issue(issue)

      assert text =~ "Title"
      assert text =~ "State"
      assert text =~ "Labels"
      assert text =~ "Comments"
      assert text =~ "Sub-issues"
      assert text =~ "MCP ticket helpers"
    end
  end

  describe "format_issue_summary/1" do
    test "formats compact issue summary" do
      issue = Fixtures.issue_map(%{number: 88, title: "Summary item", labels: ["enhancement"]})

      text = Helpers.format_issue_summary(issue)

      assert text =~ "Issue"
      assert text =~ "#88"
      assert text =~ "Summary item"
      assert text =~ "enhancement"
    end
  end

  describe "format_error/2" do
    test "formats not found" do
      assert Helpers.format_error(:not_found, "Issue #9") =~ "not found"
    end

    test "formats missing token" do
      assert Helpers.format_error(:missing_token, "ignored") == "GitHub token not configured."
    end

    test "formats generic errors" do
      assert Helpers.format_error({:unexpected, :boom}, "ignored") =~ "unexpected"
    end
  end
end
