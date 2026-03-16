defmodule Agents.Sessions.Application.UseCases.CreateTask do
  @moduledoc """
  Use case for creating a new coding task.

  Validates the instruction, then enqueues the task in the database.
  Queue orchestration is responsible for warming and promotion into processing.
  """

  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Sessions.Domain.Events.TaskQueued
  alias Agents.Sessions.Domain.Policies.QueuePolicy

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Creates a new coding task.

  Task creation always inserts in "queued" status with a queue position.

  ## Parameters
  - `attrs` - Map with:
    - `:instruction` - (required) The coding instruction
    - `:user_id` - (required) The user creating the task
  - `opts` - Keyword list with:
    - `:task_repo` - Repository module (default: TaskRepository)
    - `:task_runner_starter` - Function to start a TaskRunner (default: TaskRunnerSupervisor.start_child)
    - `:queue_orchestrator` - QueueOrchestrator module (default: QueueOrchestrator)

  ## Returns
  - `{:ok, task}` - Domain entity on success
  - `{:error, :instruction_required}` - When instruction is blank
  - `{:error, changeset}` - On validation error
  """
  @spec execute(map(), keyword()) ::
          {:ok, Agents.Sessions.Domain.Entities.Task.t()} | {:error, term()}
  def execute(attrs, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    concurrency_lock = Keyword.get(opts, :concurrency_lock, &no_concurrency_lock/2)

    with :ok <- validate_instruction(attrs) do
      user_id = attrs[:user_id] || attrs["user_id"]

      concurrency_lock.(user_id, fn ->
        create_queued_task(attrs, user_id, task_repo, session_repo, event_bus, opts)
      end)
    end
  end

  defp create_queued_task(attrs, user_id, task_repo, session_repo, event_bus, opts) do
    max_pos = task_repo.get_max_queue_position(user_id)
    queue_position = QueuePolicy.next_queue_position(max_pos)

    # Ensure a session exists for this task. Reuse an existing session if
    # session_ref_id is provided, otherwise create a new one.
    session_ref_id = resolve_session(attrs, user_id, session_repo)

    queued_attrs =
      attrs
      |> Map.merge(%{
        status: "queued",
        queue_position: queue_position,
        queued_at: DateTime.utc_now()
      })
      |> maybe_put_session_ref_id(session_ref_id)

    case task_repo.create_task(queued_attrs) do
      {:ok, schema} ->
        _ = emit_task_queued(schema, queue_position, event_bus)
        _ = maybe_link_ticket(attrs, session_ref_id, opts)
        {:ok, Task.from_schema(schema)}

      error ->
        error
    end
  end

  defp resolve_session(attrs, user_id, session_repo) do
    existing_ref = Map.get(attrs, :session_ref_id)

    if existing_ref do
      existing_ref
    else
      create_new_session(attrs, user_id, session_repo)
    end
  end

  defp create_new_session(attrs, user_id, session_repo) do
    require Logger

    instruction = attrs[:instruction] || attrs["instruction"]

    session_attrs = %{
      user_id: user_id,
      title: instruction,
      status: "active",
      container_status: "pending",
      image: Map.get(attrs, :image, "perme8-opencode")
    }

    case session_repo.create_session(session_attrs) do
      {:ok, session} ->
        session.id

      {:error, reason} ->
        Logger.warning(
          "CreateTask: failed to create session for user #{user_id}: #{inspect(reason)}"
        )

        nil
    end
  end

  defp maybe_put_session_ref_id(attrs, nil), do: attrs

  defp maybe_put_session_ref_id(attrs, session_ref_id),
    do: Map.put(attrs, :session_ref_id, session_ref_id)

  defp validate_instruction(%{instruction: instruction})
       when is_binary(instruction) and instruction != "" do
    :ok
  end

  defp validate_instruction(_), do: {:error, :instruction_required}

  defp emit_task_queued(schema, queue_position, event_bus) do
    event_bus.emit(
      TaskQueued.new(%{
        aggregate_id: schema.id,
        actor_id: schema.user_id,
        task_id: schema.id,
        user_id: schema.user_id,
        queue_position: queue_position
      })
    )
  end

  defp no_concurrency_lock(_user_id, fun), do: fun.()

  defp maybe_link_ticket(attrs, session_ref_id, opts) do
    require Logger

    ticket_number = Map.get(attrs, :ticket_number)
    ticket_linker = Keyword.get(opts, :ticket_linker, &default_ticket_linker/2)

    if is_integer(ticket_number) and ticket_number > 0 and is_binary(session_ref_id) do
      try do
        ticket_linker.(ticket_number, session_ref_id)
      rescue
        error ->
          Logger.warning(
            "CreateTask: failed to link ticket ##{ticket_number} to session #{session_ref_id}: #{inspect(error)}"
          )

          {:error, error}
      end
    else
      :skip
    end
  end

  defp default_ticket_linker(ticket_number, session_id) do
    # Runtime call to avoid compile-time boundary dependency
    apply(Agents.Tickets, :link_ticket_to_session, [ticket_number, session_id])
  end
end
