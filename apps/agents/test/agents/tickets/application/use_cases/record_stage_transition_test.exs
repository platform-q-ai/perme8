defmodule Agents.Tickets.TestDoubles.RecordStageTransitionTicketRepo do
  def get_by_id(ticket_id), do: Process.get({__MODULE__, :get_by_id}).(ticket_id)

  def update_lifecycle_stage(ticket_id, to_stage, now) do
    Process.get({__MODULE__, :update_lifecycle_stage}).(ticket_id, to_stage, now)
  end
end

defmodule Agents.Tickets.TestDoubles.RecordStageTransitionLifecycleRepo do
  def create(attrs), do: Process.get({__MODULE__, :create}).(attrs)
end

defmodule Agents.Tickets.TestDoubles.RecordStageTransitionEventBus do
  def emit(event), do: Process.get({__MODULE__, :emit}).(event)
end

defmodule Agents.Tickets.TestDoubles.RecordStageTransitionRepo do
  @moduledoc false
  def transaction(fun), do: {:ok, fun.()}
  def rollback(reason), do: throw({:rollback, reason})
end

defmodule Agents.Tickets.Application.UseCases.RecordStageTransitionTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Application.UseCases.RecordStageTransition
  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Entities.TicketLifecycleEvent
  alias Agents.Tickets.Domain.Events.TicketStageChanged
  alias Agents.Tickets.TestDoubles.RecordStageTransitionEventBus
  alias Agents.Tickets.TestDoubles.RecordStageTransitionLifecycleRepo
  alias Agents.Tickets.TestDoubles.RecordStageTransitionRepo
  alias Agents.Tickets.TestDoubles.RecordStageTransitionTicketRepo

  setup do
    Process.put({RecordStageTransitionEventBus, :emit}, fn event ->
      send(self(), {:event_emitted, event})
      :ok
    end)

    :ok
  end

  test "records transition, persists event and emits domain event" do
    now = ~U[2026-03-10 12:00:00Z]
    ticket = Ticket.new(%{id: 402, lifecycle_stage: "open"})

    Process.put({RecordStageTransitionTicketRepo, :get_by_id}, fn 402 -> {:ok, ticket} end)

    Process.put({RecordStageTransitionLifecycleRepo, :create}, fn attrs ->
      send(self(), {:created_lifecycle_event, attrs})
      {:ok, TicketLifecycleEvent.new(Map.put(attrs, :id, 1))}
    end)

    Process.put({RecordStageTransitionTicketRepo, :update_lifecycle_stage}, fn 402,
                                                                               "ready",
                                                                               ^now ->
      {:ok, Ticket.new(%{id: 402, lifecycle_stage: "ready", lifecycle_stage_entered_at: now})}
    end)

    assert {:ok, %{ticket: updated_ticket, lifecycle_event: lifecycle_event}} =
             RecordStageTransition.execute(402, "ready",
               now: now,
               repo: RecordStageTransitionRepo,
               ticket_repo: RecordStageTransitionTicketRepo,
               lifecycle_repo: RecordStageTransitionLifecycleRepo,
               event_bus: RecordStageTransitionEventBus
             )

    assert updated_ticket.lifecycle_stage == "ready"
    assert lifecycle_event.from_stage == "open"
    assert lifecycle_event.to_stage == "ready"

    assert_receive {:created_lifecycle_event,
                    %{ticket_id: 402, from_stage: "open", to_stage: "ready", trigger: "system"}}

    assert_receive {:event_emitted, %TicketStageChanged{} = domain_event}
    assert domain_event.ticket_id == 402
    assert domain_event.from_stage == "open"
    assert domain_event.to_stage == "ready"
  end

  test "rejects same-stage transition" do
    ticket = Ticket.new(%{id: 402, lifecycle_stage: "open"})
    Process.put({RecordStageTransitionTicketRepo, :get_by_id}, fn 402 -> {:ok, ticket} end)

    assert {:error, :same_stage} =
             RecordStageTransition.execute(402, "open",
               repo: RecordStageTransitionRepo,
               ticket_repo: RecordStageTransitionTicketRepo,
               lifecycle_repo: RecordStageTransitionLifecycleRepo,
               event_bus: RecordStageTransitionEventBus
             )

    refute_received {:event_emitted, _}
  end

  test "rejects invalid stage names" do
    ticket = Ticket.new(%{id: 402, lifecycle_stage: "not_a_stage"})
    Process.put({RecordStageTransitionTicketRepo, :get_by_id}, fn 402 -> {:ok, ticket} end)

    assert {:error, :invalid_from_stage} =
             RecordStageTransition.execute(402, "open",
               repo: RecordStageTransitionRepo,
               ticket_repo: RecordStageTransitionTicketRepo,
               lifecycle_repo: RecordStageTransitionLifecycleRepo,
               event_bus: RecordStageTransitionEventBus
             )

    ticket = Ticket.new(%{id: 402, lifecycle_stage: "open"})
    Process.put({RecordStageTransitionTicketRepo, :get_by_id}, fn 402 -> {:ok, ticket} end)

    assert {:error, :invalid_to_stage} =
             RecordStageTransition.execute(402, "bad",
               repo: RecordStageTransitionRepo,
               ticket_repo: RecordStageTransitionTicketRepo,
               lifecycle_repo: RecordStageTransitionLifecycleRepo,
               event_bus: RecordStageTransitionEventBus
             )

    refute_received {:event_emitted, _}
  end

  test "returns ticket_not_found when ticket does not exist" do
    Process.put({RecordStageTransitionTicketRepo, :get_by_id}, fn _id ->
      {:error, :ticket_not_found}
    end)

    assert {:error, :ticket_not_found} =
             RecordStageTransition.execute(999, "ready",
               repo: RecordStageTransitionRepo,
               ticket_repo: RecordStageTransitionTicketRepo,
               lifecycle_repo: RecordStageTransitionLifecycleRepo,
               event_bus: RecordStageTransitionEventBus
             )

    refute_received {:event_emitted, _}
  end

  test "accepts trigger override" do
    now = ~U[2026-03-10 12:00:00Z]
    ticket = Ticket.new(%{id: 402, lifecycle_stage: "open"})

    Process.put({RecordStageTransitionTicketRepo, :get_by_id}, fn 402 -> {:ok, ticket} end)

    Process.put({RecordStageTransitionLifecycleRepo, :create}, fn attrs ->
      send(self(), {:created_lifecycle_event, attrs})
      {:ok, TicketLifecycleEvent.new(Map.put(attrs, :id, 1))}
    end)

    Process.put({RecordStageTransitionTicketRepo, :update_lifecycle_stage}, fn 402,
                                                                               "ready",
                                                                               ^now ->
      {:ok, Ticket.new(%{id: 402, lifecycle_stage: "ready", lifecycle_stage_entered_at: now})}
    end)

    assert {:ok, _} =
             RecordStageTransition.execute(402, "ready",
               trigger: "manual",
               now: now,
               repo: RecordStageTransitionRepo,
               ticket_repo: RecordStageTransitionTicketRepo,
               lifecycle_repo: RecordStageTransitionLifecycleRepo,
               event_bus: RecordStageTransitionEventBus
             )

    assert_receive {:created_lifecycle_event, %{trigger: "manual"}}
    assert_receive {:event_emitted, %TicketStageChanged{trigger: "manual"}}
  end
end
