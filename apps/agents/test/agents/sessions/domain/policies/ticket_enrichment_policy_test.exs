defmodule Agents.Sessions.Domain.Policies.TicketEnrichmentPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Sessions.Domain.Entities.Ticket
  alias Agents.Sessions.Domain.Policies.TicketEnrichmentPolicy

  describe "enrich/2" do
    test "enriches a ticket from matching task instruction" do
      ticket = Ticket.new(%{number: 382, title: "Root ticket"})

      tasks = [
        Task.new(%{
          id: "task-1",
          instruction: "pick up ticket #382 and implement phase 1",
          status: "running",
          container_id: "container-1",
          error: nil,
          user_id: "user-1"
        })
      ]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)

      assert enriched.associated_task_id == "task-1"
      assert enriched.associated_container_id == "container-1"
      assert enriched.session_state == "running"
      assert enriched.task_status == "running"
      assert enriched.task_error == nil
    end

    test "returns unchanged ticket defaults when no matching task exists" do
      ticket = Ticket.new(%{number: 382, title: "Root ticket"})
      tasks = [Task.new(%{id: "task-2", instruction: "work on #999", user_id: "user-1"})]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)

      assert enriched.associated_task_id == nil
      assert enriched.associated_container_id == nil
      assert enriched.session_state == "idle"
      assert enriched.task_status == nil
      assert enriched.task_error == nil
    end
  end

  describe "enrich_all/2" do
    test "enriches tickets recursively while preserving tree structure" do
      child = Ticket.new(%{id: 2, number: 383, parent_ticket_id: 1, sub_tickets: []})
      root = Ticket.new(%{id: 1, number: 382, parent_ticket_id: nil, sub_tickets: [child]})

      tasks = [
        Task.new(%{
          id: "task-root",
          instruction: "ticket 382",
          status: "completed",
          container_id: "container-root",
          user_id: "user-1"
        }),
        Task.new(%{
          id: "task-child",
          instruction: "Fix #383",
          status: "failed",
          container_id: "container-child",
          error: "boom",
          user_id: "user-1"
        })
      ]

      [enriched_root] = TicketEnrichmentPolicy.enrich_all([root], tasks)

      assert enriched_root.number == 382
      assert enriched_root.associated_task_id == "task-root"
      assert enriched_root.session_state == "completed"

      assert [%Ticket{} = enriched_child] = enriched_root.sub_tickets
      assert enriched_child.number == 383
      assert enriched_child.associated_task_id == "task-child"
      assert enriched_child.session_state == "paused"
      assert enriched_child.task_error == "boom"
      assert enriched_child.parent_ticket_id == 1
    end
  end

  describe "extract_ticket_number/1" do
    test "extracts ticket number from instruction text" do
      assert TicketEnrichmentPolicy.extract_ticket_number("pick up ticket #382") == 382
      assert TicketEnrichmentPolicy.extract_ticket_number("Please handle ticket 401 next") == 401
      assert TicketEnrichmentPolicy.extract_ticket_number("No ticket reference") == nil
      assert TicketEnrichmentPolicy.extract_ticket_number(nil) == nil
    end
  end
end
