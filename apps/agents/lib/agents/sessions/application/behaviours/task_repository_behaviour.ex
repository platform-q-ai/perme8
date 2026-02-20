defmodule Agents.Sessions.Application.Behaviours.TaskRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the contract for task persistence.

  Implementations must provide CRUD operations for session tasks.
  """

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  @callback create_task(attrs :: map()) ::
              {:ok, TaskSchema.t()} | {:error, Ecto.Changeset.t()}

  @callback get_task(id :: Ecto.UUID.t()) :: TaskSchema.t() | nil

  @callback get_task_for_user(id :: Ecto.UUID.t(), user_id :: Ecto.UUID.t()) ::
              TaskSchema.t() | nil

  @callback update_task_status(task :: TaskSchema.t(), attrs :: map()) ::
              {:ok, TaskSchema.t()} | {:error, Ecto.Changeset.t()}

  @callback list_tasks_for_user(user_id :: Ecto.UUID.t(), opts :: keyword()) ::
              [TaskSchema.t()]

  @callback running_task_count_for_user(user_id :: Ecto.UUID.t()) :: non_neg_integer()
end
