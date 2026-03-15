defmodule Agents.Sessions.Infrastructure.Queries.TaskQueries do
  @moduledoc """
  Composable query functions for session tasks.

  All functions accept a query and return a query, allowing composition.
  """

  import Ecto.Query, warn: false

  alias Agents.Sessions.Domain.Policies.ImagePolicy
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  @doc """
  Returns the base query for tasks.
  """
  @spec base() :: Ecto.Query.t()
  def base do
    from(t in TaskSchema)
  end

  @doc """
  Filters tasks by user_id.
  """
  @spec for_user(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def for_user(query \\ base(), user_id) do
    from(t in query, where: t.user_id == ^user_id)
  end

  @doc """
  Filters tasks by status.
  """
  @spec by_status(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def by_status(query \\ base(), status) do
    from(t in query, where: t.status == ^status)
  end

  @doc """
  Filters tasks by id.
  """
  @spec by_id(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def by_id(query \\ base(), id) do
    from(t in query, where: t.id == ^id)
  end

  @doc """
  Filters tasks by a list of ids.
  """
  @spec by_ids(Ecto.Query.t(), [Ecto.UUID.t()]) :: Ecto.Query.t()
  def by_ids(query \\ base(), ids) do
    from(t in query, where: t.id in ^ids)
  end

  @doc """
  Orders tasks by most recent first.
  """
  @spec recent_first(Ecto.Query.t()) :: Ecto.Query.t()
  def recent_first(query \\ base()) do
    from(t in query, order_by: [desc: t.inserted_at, desc: t.id])
  end

  @doc """
  Limits the number of results returned.
  """
  @spec limit(Ecto.Query.t(), non_neg_integer()) :: Ecto.Query.t()
  def limit(query \\ base(), max) do
    from(t in query, limit: ^max)
  end

  @doc """
  Filters tasks by container_id.
  """
  @spec by_container(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def by_container(query \\ base(), container_id) do
    from(t in query, where: t.container_id == ^container_id)
  end

  @doc """
  Counts active tasks (status "pending", "starting", or "running") for a user.

  These are tasks that occupy a concurrency slot — they have been created
  and are in the pipeline to run or currently running.
  """
  @spec count_running(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def count_running(query \\ base(), user_id) do
    from(t in query,
      where: t.user_id == ^user_id and t.status in ["pending", "starting", "running"],
      select: count(t.id)
    )
  end

  @doc """
  Counts active heavyweight tasks (excluding light images) for a user.

  Light image tasks are excluded from this count as they don't consume
  concurrency slots in the build queue.
  """
  @spec count_running_heavyweight(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def count_running_heavyweight(query \\ base(), user_id) do
    light_images = ImagePolicy.light_image_names()

    from(t in query,
      where:
        t.user_id == ^user_id and t.status in ["pending", "starting", "running"] and
          (is_nil(t.image) or t.image not in ^light_images),
      select: count(t.id)
    )
  end

  @doc """
  Returns queued tasks for a user ordered by queue_position ascending.
  """
  @spec queued_for_user(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def queued_for_user(query \\ base(), user_id) do
    from(t in query,
      where: t.user_id == ^user_id and t.status == "queued",
      order_by: [asc: t.queue_position, asc: t.queued_at]
    )
  end

  @doc """
  Returns awaiting_feedback tasks for a user.
  """
  @spec awaiting_feedback_for_user(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def awaiting_feedback_for_user(query \\ base(), user_id) do
    from(t in query,
      where: t.user_id == ^user_id and t.status == "awaiting_feedback",
      order_by: [asc: t.inserted_at]
    )
  end

  @terminal_statuses ["completed", "failed", "cancelled"]

  @doc """
  Returns all non-terminal tasks for a user (queued, pending, starting,
  running, awaiting_feedback) in a single query.
  """
  @spec non_terminal_for_user(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def non_terminal_for_user(query \\ base(), user_id) do
    from(t in query,
      where: t.user_id == ^user_id and t.status not in ^@terminal_statuses,
      order_by: [asc: t.queue_position, asc: t.inserted_at]
    )
  end

  @doc """
  Returns the next queued task (lowest queue_position) for a user.
  """
  @spec next_queued(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def next_queued(query \\ base(), user_id) do
    from(t in query,
      where: t.user_id == ^user_id and t.status == "queued",
      order_by: [asc: t.queue_position, asc: t.queued_at],
      limit: 1
    )
  end

  @doc """
  Returns the maximum queue_position for a user's queued tasks.
  """
  @spec max_queue_position(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def max_queue_position(query \\ base(), user_id) do
    from(t in query,
      where: t.user_id == ^user_id and t.status == "queued",
      select: max(t.queue_position)
    )
  end

  @doc """
  Returns sessions grouped by container_id for a user.

  Each session is represented as a map with the container_id,
  the latest task's status, the first task's instruction (as title),
  task count, timestamps, duration source fields (started_at, completed_at),
  and the latest task's session_summary.
  """
  @spec sessions_for_user(Ecto.UUID.t()) :: Ecto.Query.t()
  def sessions_for_user(user_id) do
    from(t in TaskSchema,
      where: t.user_id == ^user_id and not is_nil(t.container_id),
      group_by: t.container_id,
      select: %{
        container_id: t.container_id,
        task_count: count(t.id),
        latest_status: fragment("(array_agg(? ORDER BY ? DESC))[1]", t.status, t.inserted_at),
        latest_task_id:
          fragment("(array_agg(CAST(? AS text) ORDER BY ? DESC))[1]", t.id, t.inserted_at),
        latest_error: fragment("(array_agg(? ORDER BY ? DESC))[1]", t.error, t.inserted_at),
        title: fragment("(array_agg(? ORDER BY ? ASC))[1]", t.instruction, t.inserted_at),
        image: fragment("(array_agg(? ORDER BY ? ASC))[1]", t.image, t.inserted_at),
        latest_at: max(t.inserted_at),
        created_at: min(t.inserted_at),
        started_at: min(t.started_at),
        completed_at:
          type(
            fragment("(array_agg(? ORDER BY ? DESC))[1]", t.completed_at, t.inserted_at),
            :utc_datetime
          ),
        todo_items: fragment("(array_agg(? ORDER BY ? DESC))[1]", t.todo_items, t.inserted_at),
        session_summary:
          fragment(
            "(array_agg(? ORDER BY ? DESC))[1]",
            t.session_summary,
            t.inserted_at
          )
      },
      order_by: [desc: max(t.inserted_at)]
    )
  end
end
