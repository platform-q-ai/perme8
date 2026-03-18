defmodule Agents.Sessions.Application do
  @moduledoc """
  Application layer boundary for the Sessions bounded context.

  Contains behaviours, use cases, and configuration.
  """

  use Boundary,
    top_level?: true,
    deps: [Agents.Sessions.Domain],
    exports: [
      Behaviours.ContainerProviderBehaviour,
      Behaviours.OpencodeClientBehaviour,
      Behaviours.TaskRepositoryBehaviour,
      Behaviours.SessionRepositoryBehaviour,
      Behaviours.QueueOrchestratorBehaviour,
      Services.AuthRefresher,
      UseCases.CreateTask,
      UseCases.CancelTask,
      UseCases.DeleteSession,
      UseCases.DeleteTask,
      UseCases.RefreshAuthAndResume,
      UseCases.ResumeTask,
      UseCases.GetTask,
      UseCases.ListTasks,
      UseCases.BuildSnapshot,
      UseCases.PromoteTask,
      UseCases.ScheduleRetry,
      UseCases.CreateInteraction,
      SessionTransition,
      UseCases.PauseSession,
      UseCases.ResumeSession,
      UseCases.CompleteSession,
      UseCases.FailSession,
      SessionsConfig
    ]
end
