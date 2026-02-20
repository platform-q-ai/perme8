defmodule Agents.Sessions.Application.Behaviours.TaskRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the contract for task persistence.

  Implementations must provide CRUD operations for session tasks.
  """

  @type task :: struct()
  @type task_id :: Ecto.UUID.t()
  @type user_id :: Ecto.UUID.t()
  @type attrs :: map()

  @callback create_task(attrs) ::
              {:ok, task} | {:error, Ecto.Changeset.t()}

  @callback get_task(task_id) :: task | nil

  @callback get_task_for_user(task_id, user_id) :: task | nil

  @callback update_task_status(task, attrs) ::
              {:ok, task} | {:error, Ecto.Changeset.t()}

  @callback list_tasks_for_user(user_id, opts :: keyword()) :: [task]

  @callback running_task_count_for_user(user_id) :: non_neg_integer()
end
