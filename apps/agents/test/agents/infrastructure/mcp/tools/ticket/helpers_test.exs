defmodule Agents.Infrastructure.Mcp.Tools.Ticket.HelpersTest do
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Tickets.Domain.Entities.Ticket

  describe "get_param/2" do
    test "finds value by atom key" do
      assert Helpers.get_param(%{number: 42}, :number) == 42
    end

    test "falls back to string key" do
      assert Helpers.get_param(%{"number" => 42}, :number) == 42
    end

    test "returns nil when key is absent" do
      assert Helpers.get_param(%{}, :number) == nil
    end
  end

  describe "format_ticket/1" do
    test "formats ticket entity as detailed markdown" do
      ticket = %Ticket{
        number: 77,
        title: "MCP ticket helpers",
        state: "open",
        labels: ["enhancement", "mcp"],
        body: "Some body text",
        url: "https://github.com/platform-q-ai/perme8/issues/77",
        sub_tickets: [%Ticket{number: 11, title: "Sub 1"}, %Ticket{number: 12, title: "Sub 2"}],
        blocked_by: [%Ticket{number: 5, title: "Blocker"}],
        blocks: []
      }

      text = Helpers.format_ticket(ticket)

      assert text =~ "Ticket #77"
      assert text =~ "MCP ticket helpers"
      assert text =~ "enhancement, mcp"
      assert text =~ "Some body text"
      assert text =~ "#11"
      assert text =~ "#12"
      assert text =~ "#5"
    end

    test "handles nil body and empty collections" do
      ticket = %Ticket{
        number: 99,
        title: "Empty",
        state: "open",
        body: nil,
        labels: [],
        sub_tickets: [],
        blocked_by: [],
        blocks: []
      }

      text = Helpers.format_ticket(ticket)

      assert text =~ "(empty)"
      assert text =~ "None"
    end
  end

  describe "format_ticket_summary/1" do
    test "formats compact ticket summary" do
      ticket = %Ticket{
        number: 88,
        title: "Summary item",
        state: "open",
        labels: ["enhancement"]
      }

      text = Helpers.format_ticket_summary(ticket)

      assert text =~ "Ticket #88"
      assert text =~ "Summary item"
      assert text =~ "enhancement"
    end
  end

  describe "format_error/2" do
    test "formats not found" do
      assert Helpers.format_error(:not_found, "Ticket #9") =~ "not found"
    end

    test "formats ticket_not_found" do
      assert Helpers.format_error(:ticket_not_found, "Ticket #9") =~ "not found"
    end

    test "formats no_changes" do
      assert Helpers.format_error(:no_changes, nil) =~ "No updatable fields"
    end

    test "formats parent_not_found" do
      assert Helpers.format_error(:parent_not_found, nil) =~ "Parent ticket not found"
    end

    test "formats child_not_found" do
      assert Helpers.format_error(:child_not_found, nil) =~ "Child ticket not found"
    end

    test "formats missing token" do
      assert Helpers.format_error(:missing_token, "ignored") == "GitHub token not configured."
    end

    test "formats generic errors without leaking internals" do
      text = Helpers.format_error({:unexpected, :boom}, "ignored")
      assert text =~ "unexpected error"
      refute text =~ "boom"
    end
  end
end
