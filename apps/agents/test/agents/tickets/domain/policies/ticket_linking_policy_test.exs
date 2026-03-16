defmodule Agents.Tickets.Domain.Policies.TicketLinkingPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Policies.TicketLinkingPolicy

  describe "valid_ticket_number?/1" do
    test "returns true for positive integers" do
      assert TicketLinkingPolicy.valid_ticket_number?(1)
      assert TicketLinkingPolicy.valid_ticket_number?(42)
      assert TicketLinkingPolicy.valid_ticket_number?(999)
    end

    test "returns false for zero" do
      refute TicketLinkingPolicy.valid_ticket_number?(0)
    end

    test "returns false for negative integers" do
      refute TicketLinkingPolicy.valid_ticket_number?(-1)
      refute TicketLinkingPolicy.valid_ticket_number?(-42)
    end

    test "returns false for nil" do
      refute TicketLinkingPolicy.valid_ticket_number?(nil)
    end

    test "returns false for non-integer types" do
      refute TicketLinkingPolicy.valid_ticket_number?("42")
      refute TicketLinkingPolicy.valid_ticket_number?(42.0)
      refute TicketLinkingPolicy.valid_ticket_number?(:atom)
    end
  end

  describe "should_link?/1" do
    test "returns true when ticket_number is a positive integer" do
      assert TicketLinkingPolicy.should_link?(42)
      assert TicketLinkingPolicy.should_link?(1)
    end

    test "returns false when ticket_number is nil" do
      refute TicketLinkingPolicy.should_link?(nil)
    end

    test "returns false when ticket_number is invalid" do
      refute TicketLinkingPolicy.should_link?(0)
      refute TicketLinkingPolicy.should_link?(-5)
      refute TicketLinkingPolicy.should_link?("42")
    end
  end
end
