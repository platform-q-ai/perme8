defmodule Agents.Sessions.Domain.Policies.TicketHierarchyPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Ticket
  alias Agents.Sessions.Domain.Policies.TicketHierarchyPolicy

  describe "build_tree/1" do
    test "builds root-only list with nested sub_tickets" do
      root = Ticket.new(%{id: 1, number: 382, title: "Root", parent_ticket_id: nil, position: 2})

      child =
        Ticket.new(%{id: 2, number: 383, title: "Child", parent_ticket_id: 1, position: 1})

      other_root =
        Ticket.new(%{id: 3, number: 384, title: "Other root", parent_ticket_id: nil, position: 0})

      tree = TicketHierarchyPolicy.build_tree([root, child, other_root])

      assert Enum.map(tree, & &1.number) == [382, 384]
      assert Enum.map(hd(tree).sub_tickets, & &1.number) == [383]
    end

    test "treats orphaned child tickets as roots" do
      orphan =
        Ticket.new(%{id: 2, number: 383, title: "Orphan", parent_ticket_id: 999, position: 1})

      tree = TicketHierarchyPolicy.build_tree([orphan])
      assert Enum.map(tree, & &1.number) == [383]
    end

    test "preserves input ordering within each level" do
      root_a = Ticket.new(%{id: 1, number: 10, parent_ticket_id: nil, position: 30})
      root_b = Ticket.new(%{id: 2, number: 20, parent_ticket_id: nil, position: 20})
      child_b = Ticket.new(%{id: 4, number: 40, parent_ticket_id: 1, position: 10})
      child_a = Ticket.new(%{id: 3, number: 30, parent_ticket_id: 1, position: 20})

      tree = TicketHierarchyPolicy.build_tree([root_a, root_b, child_b, child_a])

      assert Enum.map(tree, & &1.number) == [10, 20]
      assert Enum.map(hd(tree).sub_tickets, & &1.number) == [40, 30]
    end
  end

  describe "circular_reference?/2" do
    test "detects circular parent assignment" do
      tickets = [
        Ticket.new(%{id: 1, number: 10, parent_ticket_id: 2}),
        Ticket.new(%{id: 2, number: 20, parent_ticket_id: 3}),
        Ticket.new(%{id: 3, number: 30, parent_ticket_id: nil})
      ]

      assert TicketHierarchyPolicy.circular_reference?(tickets, {3, 1})
    end

    test "returns false for valid parent assignment" do
      tickets = [
        Ticket.new(%{id: 1, number: 10, parent_ticket_id: nil}),
        Ticket.new(%{id: 2, number: 20, parent_ticket_id: nil}),
        Ticket.new(%{id: 3, number: 30, parent_ticket_id: nil})
      ]

      refute TicketHierarchyPolicy.circular_reference?(tickets, {3, 1})
    end
  end

  describe "sub_ticket_summary/1" do
    test "returns closed and total counts" do
      ticket =
        Ticket.new(%{
          sub_tickets: [
            Ticket.new(%{state: "closed"}),
            Ticket.new(%{state: "closed"}),
            Ticket.new(%{state: "open"})
          ]
        })

      assert TicketHierarchyPolicy.sub_ticket_summary(ticket) == {2, 3}
    end

    test "returns {0, 0} for tickets without sub_tickets" do
      assert TicketHierarchyPolicy.sub_ticket_summary(Ticket.new(%{sub_tickets: []})) == {0, 0}
      assert TicketHierarchyPolicy.sub_ticket_summary(Ticket.new(%{sub_tickets: nil})) == {0, 0}
    end
  end

  describe "sub_ticket_summary_text/1" do
    test "formats closed summary text" do
      ticket =
        Ticket.new(%{
          sub_tickets: [
            Ticket.new(%{state: "closed"}),
            Ticket.new(%{state: "closed"}),
            Ticket.new(%{state: "open"})
          ]
        })

      assert TicketHierarchyPolicy.sub_ticket_summary_text(ticket) == "2/3 closed"
    end

    test "formats open summary text" do
      ticket =
        Ticket.new(%{
          sub_tickets: [
            Ticket.new(%{state: "open"}),
            Ticket.new(%{state: "open"}),
            Ticket.new(%{state: "open"})
          ]
        })

      assert TicketHierarchyPolicy.sub_ticket_summary_text(ticket) == "3 sub-issues"
    end
  end

  describe "max_depth/0" do
    test "returns nesting cap of 2" do
      assert TicketHierarchyPolicy.max_depth() == 2
    end
  end
end
