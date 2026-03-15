defmodule Agents.Tickets.Domain.Policies.TicketDependencyPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Policies.TicketDependencyPolicy

  describe "circular_dependency?/3" do
    test "detects simple cycle: A→B exists, adding B→A" do
      edges = [{1, 2}]
      assert TicketDependencyPolicy.circular_dependency?(edges, 2, 1) == true
    end

    test "detects transitive cycle: A→B, B→C exist, adding C→A" do
      edges = [{1, 2}, {2, 3}]
      assert TicketDependencyPolicy.circular_dependency?(edges, 3, 1) == true
    end

    test "detects long chain cycle: A→B→C→D, adding D→A" do
      edges = [{1, 2}, {2, 3}, {3, 4}]
      assert TicketDependencyPolicy.circular_dependency?(edges, 4, 1) == true
    end

    test "no cycle when edge does not create a path back" do
      edges = [{1, 2}]
      assert TicketDependencyPolicy.circular_dependency?(edges, 3, 1) == false
    end

    test "no cycle with empty edges" do
      assert TicketDependencyPolicy.circular_dependency?([], 1, 2) == false
    end

    test "self-reference is always a cycle" do
      assert TicketDependencyPolicy.circular_dependency?([], 1, 1) == true
    end

    test "no cycle with parallel branches" do
      # A→B, A→C, adding D→B is fine
      edges = [{1, 2}, {1, 3}]
      assert TicketDependencyPolicy.circular_dependency?(edges, 4, 2) == false
    end

    test "detects cycle in diamond shape: A→B, A→C, B→D, C→D, adding D→A" do
      edges = [{1, 2}, {1, 3}, {2, 4}, {3, 4}]
      assert TicketDependencyPolicy.circular_dependency?(edges, 4, 1) == true
    end
  end

  describe "duplicate_dependency?/2" do
    test "returns true when edge exists" do
      edges = [{1, 2}, {3, 4}]
      assert TicketDependencyPolicy.duplicate_dependency?(edges, {1, 2}) == true
    end

    test "returns false when edge does not exist" do
      edges = [{1, 2}, {3, 4}]
      assert TicketDependencyPolicy.duplicate_dependency?(edges, {2, 1}) == false
    end

    test "returns false for empty edges" do
      assert TicketDependencyPolicy.duplicate_dependency?([], {1, 2}) == false
    end
  end

  describe "valid_dependency?/2" do
    test "returns true when IDs are different" do
      assert TicketDependencyPolicy.valid_dependency?(1, 2) == true
    end

    test "returns false for self-reference" do
      assert TicketDependencyPolicy.valid_dependency?(1, 1) == false
    end
  end
end
