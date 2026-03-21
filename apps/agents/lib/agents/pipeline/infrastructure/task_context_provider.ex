defmodule Agents.Pipeline.Infrastructure.TaskContextProvider do
  @moduledoc false

  @behaviour Agents.Pipeline.Application.Behaviours.TaskContextProviderBehaviour

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  @impl true
  def get_task_context(task_id) do
    case Repo.get(TaskSchema, task_id) do
      nil ->
        {:error, :task_not_found}

      task ->
        {:ok,
         %{
           user_id: task.user_id,
           container_id: task.container_id,
           instruction: task.instruction
         }}
    end
  end
end
