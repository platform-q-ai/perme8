defmodule Agents.Sessions.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Sessions bounded context.

  Contains implementation details for persistence and external services:
  - Schemas: TaskSchema, ProjectTicketSchema
  - Queries: TaskQueries
  - Repositories: TaskRepository, ProjectTicketRepository
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
      Schemas.ProjectTicketSchema,
      Repositories.TaskRepository,
      Repositories.ProjectTicketRepository,
      Queries.TaskQueries,
      OrphanRecovery,
      TaskRunnerSupervisor,
      QueueManager,
      QueueManagerSupervisor,
      QueueMirror,
      QueueOrchestrator,
      QueueOrchestratorSupervisor,
      TicketSyncServer
    ]
end
