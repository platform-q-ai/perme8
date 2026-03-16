defmodule Agents.Sessions.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Sessions bounded context.

  Contains implementation details for persistence and external services:
  - Schemas: TaskSchema
  - Queries: TaskQueries
  - Repositories: TaskRepository
  - Adapters: DockerAdapter
  - Clients: OpencodeClient
  - TaskRunner, TaskRunnerSupervisor
  """

  use Boundary,
    top_level?: true,
    deps: [
      Agents.Sessions.Domain,
      Agents.Sessions.Application,
      Agents.Repo
    ],
    exports: [
      Schemas.TaskSchema,
      Schemas.SessionSchema,
      Repositories.TaskRepository,
      Repositories.SessionRepository,
      Queries.TaskQueries,
      Queries.SessionQueries,
      OrphanRecovery,
      TaskRunnerSupervisor,
      QueueOrchestrator,
      QueueOrchestratorSupervisor,
      SdkEventDebouncer,
      SdkEventHandler
    ]
end
