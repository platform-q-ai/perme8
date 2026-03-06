defmodule Agents.Sessions.Application.UseCases.PromoteTask do
  @moduledoc """
  Use case that promotes queued tasks to pending based on queue engine rules.

  Identifies promotable tasks from the snapshot, transitions them to pending,
  and emits domain events.
  """

  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Domain.Events.{TaskLaneChanged, TaskPromoted}
  alias Agents.Sessions.Domain.Policies.QueueEngine

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_event_bus Perme8.Events.EventBus

  @spec execute(QueueSnapshot.t(), keyword()) :: {:ok, [map()]}
  def execute(snapshot, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    # Pass 1: promote all queued light image tasks (bypass concurrency limit)
    light_entries = QueueEngine.light_image_tasks_to_promote(snapshot)
    light_promoted = promote_entries(light_entries, snapshot.user_id, task_repo, event_bus)

    # Pass 2: promote heavyweight tasks up to available concurrency slots
    available = QueueSnapshot.available_slots(snapshot)
    heavyweight_entries = QueueEngine.heavyweight_tasks_to_promote(snapshot, available)
    heavy_promoted = promote_entries(heavyweight_entries, snapshot.user_id, task_repo, event_bus)

    {:ok, light_promoted ++ heavy_promoted}
  end

  defp promote_entries(entries, user_id, task_repo, event_bus) do
    Enum.map(entries, fn entry ->
      task = task_repo.get_task(entry.task_id)

      {:ok, updated} =
        task_repo.update_task_status(task, %{
          status: "pending",
          queue_position: nil,
          queued_at: nil
        })

      emit_events(entry, user_id, event_bus)
      updated
    end)
  end

  defp emit_events(entry, user_id, event_bus) do
    event_bus.emit(
      TaskPromoted.new(%{
        aggregate_id: entry.task_id,
        actor_id: user_id,
        task_id: entry.task_id,
        user_id: user_id
      })
    )

    event_bus.emit(
      TaskLaneChanged.new(%{
        aggregate_id: entry.task_id,
        actor_id: user_id,
        task_id: entry.task_id,
        user_id: user_id,
        from_lane: entry.lane,
        to_lane: :processing
      })
    )
  end
end
