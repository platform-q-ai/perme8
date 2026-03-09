defmodule Agents.Sessions.Domain do
  @moduledoc """
  Domain layer boundary for the Sessions bounded context.

  Contains pure business logic with no external dependencies:
  - Entities: Task, Session, TodoItem, TodoList, QueueSnapshot, LaneEntry, Ticket
  - Policies: TaskPolicy, SessionLifecyclePolicy, QueueEngine, QueuePolicy, ImagePolicy, RetryPolicy, TicketHierarchyPolicy, TicketEnrichmentPolicy
  - Events: Task lifecycle events, Session lifecycle events, Queue events
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Task,
      Entities.TodoItem,
      Entities.TodoList,
      Entities.Session,
      Entities.QueueSnapshot,
      Entities.LaneEntry,
      Policies.TaskPolicy,
      Policies.ImagePolicy,
      Policies.QueuePolicy,
      Policies.QueueEngine,
      Policies.RetryPolicy,
      Policies.SessionLifecyclePolicy,
      Events.TaskCreated,
      Events.TaskCompleted,
      Events.TaskFailed,
      Events.TaskCancelled,
      Events.TaskQueued,
      Events.TaskDeprioritised,
      Events.TaskPromoted,
      Events.TaskLaneChanged,
      Events.TaskRetryScheduled,
      Events.QueueSnapshotUpdated,
      Events.SessionStateChanged,
      Events.SessionWarmingStarted,
      Events.SessionWarmed
    ]
end
