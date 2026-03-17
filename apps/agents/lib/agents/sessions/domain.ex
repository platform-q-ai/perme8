defmodule Agents.Sessions.Domain do
  @moduledoc """
  Domain layer boundary for the Sessions bounded context.

  Contains pure business logic with no external dependencies:
  - Entities: Task, Session, TodoItem, TodoList, QueueSnapshot, LaneEntry
  - Policies: TaskPolicy, SessionLifecyclePolicy, QueueEngine, QueuePolicy, ImagePolicy, RetryPolicy, SdkEventPolicy, SdkEventTypes, SdkErrorPolicy
  - Events: Task lifecycle events, Session lifecycle events, Queue events, SDK session events
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Task,
      Entities.TodoItem,
      Entities.TodoList,
      Entities.Session,
      Entities.SessionRecord,
      Entities.QueueSnapshot,
      Entities.LaneEntry,
      Entities.Interaction,
      Policies.TaskPolicy,
      Policies.InteractionPolicy,
      Policies.ContainerLifecyclePolicy,
      Policies.SessionStateMachinePolicy,
      Policies.ImagePolicy,
      Policies.QueuePolicy,
      Policies.QueueEngine,
      Policies.RetryPolicy,
      Policies.SessionLifecyclePolicy,
      Policies.SdkErrorPolicy,
      Policies.SdkEventPolicy,
      Policies.SdkEventTypes,
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
      Events.SessionWarmed,
      Events.SessionCompacted,
      Events.SessionDiffProduced,
      Events.SessionErrorOccurred,
      Events.SessionFileEdited,
      Events.SessionMessageUpdated,
      Events.SessionMetadataUpdated,
      Events.SessionPermissionRequested,
      Events.SessionPermissionResolved,
      Events.SessionRetrying,
      Events.SessionServerConnected,
      Events.SessionContainerStatusChanged,
      Events.SessionPaused,
      Events.SessionResumed
    ]
end
