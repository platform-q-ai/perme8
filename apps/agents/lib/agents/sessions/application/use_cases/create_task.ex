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
    session_ref_id = resolve_session(attrs, user_id, session_repo, opts)

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
        {:ok, Task.from_schema(schema)}

      error ->
        error
    end
  end

  defp resolve_session(attrs, user_id, session_repo, opts) do
    existing_ref = Map.get(attrs, :session_ref_id)

    if existing_ref do
      existing_ref
    else
      ticket_number = extract_ticket_number(attrs)

      with {:ticket, ticket_number} when is_integer(ticket_number) <- {:ticket, ticket_number},
           resolver when is_function(resolver, 1) <- Keyword.get(opts, :ticket_session_resolver),
           session_id when is_binary(session_id) <- resolver.(ticket_number) do
        session_id
      else
        _ ->
          session_id = create_new_session(attrs, user_id, session_repo)

          maybe_link_ticket_session(
            ticket_number,
            session_id,
            Keyword.get(opts, :ticket_session_linker)
          )

          session_id
      end
    end
  end

  defp extract_ticket_number(attrs) do
    attrs
    |> instruction_from_attrs()
    |> parse_ticket_number()
  end

  defp instruction_from_attrs(attrs) do
    Map.get(attrs, :instruction) || Map.get(attrs, "instruction")
  end

  @ticket_number_regex ~r/(?:^|\s)(?:#|ticket\s+)(\d+)\b/i

  defp parse_ticket_number(instruction) when is_binary(instruction) do
    case Regex.run(@ticket_number_regex, instruction) do
      [_, value] -> String.to_integer(value)
      _ -> nil
    end
  end

  defp parse_ticket_number(_), do: nil

  defp maybe_link_ticket_session(ticket_number, session_id, linker)
       when is_integer(ticket_number) and is_binary(session_id) and is_function(linker, 2) do
    _ = linker.(ticket_number, session_id)
    :ok
  rescue
    _ -> :ok
  end

  defp maybe_link_ticket_session(_ticket_number, _session_id, _linker), do: :ok

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
end
