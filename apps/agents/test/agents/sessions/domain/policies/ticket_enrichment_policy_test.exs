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
      assert enriched_child.session_state == "failed"
      assert enriched_child.task_error == "boom"
      assert enriched_child.parent_ticket_id == 1
    end
  end

  describe "persisted task_id preference" do
    test "prefers persisted associated_task_id over regex match" do
      # Ticket has a persisted task_id pointing to task-persisted
      ticket =
        Ticket.new(%{
          number: 382,
          title: "Root ticket",
          associated_task_id: "task-persisted"
        })

      tasks = [
        Task.new(%{
          id: "task-persisted",
          instruction: "some unrelated instruction",
          status: "completed",
          container_id: "container-persisted",
          user_id: "user-1"
        }),
        Task.new(%{
          id: "task-regex",
          instruction: "pick up ticket #382",
          status: "running",
          container_id: "container-regex",
          user_id: "user-1"
        })
      ]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)

      assert enriched.associated_task_id == "task-persisted"
      assert enriched.associated_container_id == "container-persisted"
      assert enriched.session_state == "completed"
    end

    test "falls back to regex when persisted task_id is not found in tasks" do
      ticket =
        Ticket.new(%{
          number: 382,
          title: "Root ticket",
          associated_task_id: "deleted-task"
        })

      tasks = [
        Task.new(%{
          id: "task-regex",
          instruction: "pick up ticket #382",
          status: "running",
          container_id: "container-regex",
          user_id: "user-1"
        })
      ]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)

      # Persisted task_id not found, but regex matched — falls through to nil
      # from the id lookup, so enrichment clears the association
      assert enriched.associated_task_id == nil
      assert enriched.session_state == "idle"
    end

    test "falls back to regex when persisted task_id is nil" do
      ticket = Ticket.new(%{number: 382, title: "Root ticket"})

      tasks = [
        Task.new(%{
          id: "task-regex",
          instruction: "pick up ticket #382",
          status: "running",
          container_id: "container-regex",
          user_id: "user-1"
        })
      ]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)

      assert enriched.associated_task_id == "task-regex"
      assert enriched.associated_container_id == "container-regex"
      assert enriched.session_state == "running"
    end

    test "enrich_all preserves persisted task_id through tree enrichment" do
      child =
        Ticket.new(%{
          id: 2,
          number: 383,
          parent_ticket_id: 1,
          sub_tickets: [],
          associated_task_id: "task-child-persisted"
        })

      root =
        Ticket.new(%{
          id: 1,
          number: 382,
          parent_ticket_id: nil,
          sub_tickets: [child],
          associated_task_id: "task-root-persisted"
        })

      tasks = [
        Task.new(%{
          id: "task-root-persisted",
          instruction: "unrelated instruction",
          status: "completed",
          container_id: "container-root",
          user_id: "user-1"
        }),
        Task.new(%{
          id: "task-child-persisted",
          instruction: "also unrelated",
          status: "running",
          container_id: "container-child",
          user_id: "user-1"
        })
      ]

      [enriched_root] = TicketEnrichmentPolicy.enrich_all([root], tasks)

      assert enriched_root.associated_task_id == "task-root-persisted"
      assert enriched_root.session_state == "completed"

      assert [enriched_child] = enriched_root.sub_tickets
      assert enriched_child.associated_task_id == "task-child-persisted"
      assert enriched_child.session_state == "running"
    end
  end

  describe "lifecycle-aware session_state enrichment" do
    test "maps queued without container to queued_cold" do
      ticket = Ticket.new(%{number: 382, title: "Root ticket"})

      tasks = [
        Task.new(%{id: "task-1", instruction: "ticket #382", status: "queued", user_id: "user-1"})
      ]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)
      assert enriched.session_state == "queued_cold"
    end

    test "maps queued with real container to queued_warm" do
      ticket = Ticket.new(%{number: 382, title: "Root ticket"})

      tasks = [
        Task.new(%{
          id: "task-1",
          instruction: "ticket #382",
          status: "queued",
          container_id: "container-1",
          user_id: "user-1"
        })
      ]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)
      assert enriched.session_state == "queued_warm"
    end

    test "maps pending with container and no port to warming" do
      ticket = Ticket.new(%{number: 382, title: "Root ticket"})

      tasks = [
        Task.new(%{
          id: "task-1",
          instruction: "ticket #382",
          status: "pending",
          container_id: "container-1",
          container_port: nil,
          user_id: "user-1"
        })
      ]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)
      assert enriched.session_state == "warming"
    end

    test "maps cancelled to cancelled" do
      ticket = Ticket.new(%{number: 382, title: "Root ticket"})

      tasks = [
        Task.new(%{
          id: "task-1",
          instruction: "ticket #382",
          status: "cancelled",
          user_id: "user-1"
        })
      ]

      enriched = TicketEnrichmentPolicy.enrich(ticket, tasks)
      assert enriched.session_state == "cancelled"
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
