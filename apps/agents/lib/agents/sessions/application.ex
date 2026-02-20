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
      UseCases.CreateTask,
      UseCases.CancelTask,
      UseCases.GetTask,
      UseCases.ListTasks,
      SessionsConfig
    ]
end
