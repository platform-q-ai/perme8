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
      Identity.Repo
    ],
    exports: [
      Schemas.TaskSchema,
      Repositories.TaskRepository,
      Queries.TaskQueries,
      TaskRunnerSupervisor
    ]
end
