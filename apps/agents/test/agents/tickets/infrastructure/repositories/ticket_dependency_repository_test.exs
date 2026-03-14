defmodule Agents.Tickets.Infrastructure.Repositories.TicketDependencyRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Repositories.TicketDependencyRepository

  setup do
    {:ok, ticket_a} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 600,
        title: "Repo Test A",
        state: "open"
      })

    {:ok, ticket_b} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 601,
        title: "Repo Test B",
        state: "open"
      })

    {:ok, ticket_c} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 602,
        title: "Repo Test C",
        state: "open"
      })

    %{ticket_a: ticket_a, ticket_b: ticket_b, ticket_c: ticket_c}
  end

  describe "add_dependency/2" do
    test "inserts a dependency record", %{ticket_a: a, ticket_b: b} do
      assert {:ok, dep} = TicketDependencyRepository.add_dependency(a.id, b.id)
      assert dep.blocker_ticket_id == a.id
      assert dep.blocked_ticket_id == b.id
    end

    test "returns error for duplicate", %{ticket_a: a, ticket_b: b} do
      assert {:ok, _} = TicketDependencyRepository.add_dependency(a.id, b.id)
      assert {:error, _changeset} = TicketDependencyRepository.add_dependency(a.id, b.id)
    end
  end

  describe "remove_dependency/2" do
    test "removes an existing dependency", %{ticket_a: a, ticket_b: b} do
      {:ok, _} = TicketDependencyRepository.add_dependency(a.id, b.id)
      assert :ok = TicketDependencyRepository.remove_dependency(a.id, b.id)
    end

    test "returns :not_found for non-existent", %{ticket_a: a, ticket_b: b} do
      assert {:error, :not_found} = TicketDependencyRepository.remove_dependency(a.id, b.id)
    end
  end

  describe "list_edges/0" do
    test "returns all dependency edges as tuples", %{ticket_a: a, ticket_b: b, ticket_c: c} do
      {:ok, _} = TicketDependencyRepository.add_dependency(a.id, b.id)
      {:ok, _} = TicketDependencyRepository.add_dependency(b.id, c.id)

      edges = TicketDependencyRepository.list_edges()
      assert {a.id, b.id} in edges
      assert {b.id, c.id} in edges
      assert length(edges) == 2
    end

    test "returns empty list when no dependencies" do
      assert TicketDependencyRepository.list_edges() == []
    end
  end

  describe "ticket_exists?/1" do
    test "returns true for existing ticket", %{ticket_a: a} do
      assert TicketDependencyRepository.ticket_exists?(a.id)
    end

    test "returns false for non-existent ticket" do
      refute TicketDependencyRepository.ticket_exists?(999_999)
    end
  end

  describe "search_tickets/2" do
    test "finds tickets by exact number", %{ticket_a: a, ticket_b: b} do
      results = TicketDependencyRepository.search_tickets("600", b.id)
      assert length(results) == 1
      assert hd(results).id == a.id
    end

    test "finds tickets by title substring", %{ticket_a: a, ticket_b: b} do
      results = TicketDependencyRepository.search_tickets("Repo Test", a.id)
      # Should find B and C but not A (excluded)
      ids = Enum.map(results, & &1.id)
      refute a.id in ids
      assert b.id in ids
    end

    test "excludes the specified ticket", %{ticket_a: a} do
      results = TicketDependencyRepository.search_tickets("Repo Test A", a.id)
      ids = Enum.map(results, & &1.id)
      refute a.id in ids
    end

    test "returns empty for no matches", %{ticket_a: a} do
      results = TicketDependencyRepository.search_tickets("zzz_nonexistent_zzz", a.id)
      assert results == []
    end

    test "sanitizes SQL wildcards in search", %{ticket_a: a} do
      # Searching for "%" should not match all tickets
      results = TicketDependencyRepository.search_tickets("%", a.id)
      assert results == []
    end
  end
end
