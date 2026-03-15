defmodule AgentsWeb.DashboardLive.Helpers.SessionStateHelpers do
  @moduledoc """
  Session state derivation, sorting, and lifecycle management for the dashboard LiveView.

  Contains functions for building session entries from tasks, managing the
  sessions list, task snapshots, lifecycle state transitions, and session
  subscription management.
  """

  import Phoenix.Component, only: [assign: 2]
  import AgentsWeb.DashboardLive.Helpers, only: [active_task?: 1]

  alias Agents.Sessions
  alias AgentsWeb.DashboardLive.SessionStateMachine

  def assign_session_state(socket) do
    assign(socket,
      session_title: nil,
      session_model: nil,
      session_tokens: nil,
      session_cost: nil,
      session_summary: nil,
      parent_session_id: nil,
      child_session_ids: MapSet.new(),
      output_parts: [],
      pending_question: nil,
      confirmed_user_messages: [],
      optimistic_user_messages: [],
      user_message_ids: MapSet.new(),
      subtask_message_ids: MapSet.new(),
      todo_items: [],
      queued_messages: []
    )
  end

  @doc "Inserts or replaces a session entry derived from a task in the sessions list."
  def upsert_session_from_task(sessions, task) do
    task_id = Map.get(task, :id)
    task_container_id = Map.get(task, :container_id)
    session_update = build_session_from_task(task, task_id, task_container_id)

    {existing, rest} = split_matching_sessions(sessions, task_id, task_container_id)

    merged =
      case existing do
        [first | _] ->
          safe_update = drop_default_fields(session_update, task)
          Map.merge(first, safe_update)

        [] ->
          session_update
      end

    sort_sessions_for_sidebar([merged | rest])
  end

  def build_session_from_task(task, task_id, task_container_id) do
    %{
      container_id: derive_container_id(task_container_id, task_id),
      task_count: 1,
      latest_status: Map.get(task, :status, "queued"),
      latest_task_id: task_id,
      latest_error: Map.get(task, :error),
      title: Map.get(task, :instruction, "New session"),
      image: Map.get(task, :image, Sessions.default_image()),
      latest_at: Map.get(task, :updated_at) || Map.get(task, :inserted_at) || DateTime.utc_now(),
      created_at: Map.get(task, :inserted_at) || DateTime.utc_now(),
      started_at: Map.get(task, :started_at),
      completed_at: Map.get(task, :completed_at),
      session_summary: Map.get(task, :session_summary),
      todo_items: Map.get(task, :todo_items) || %{"items" => []}
    }
  end

  def drop_default_fields(session_update, task) do
    fields_to_keep =
      [:latest_status, :latest_task_id, :latest_error, :latest_at]

    fields_to_keep =
      if is_binary(Map.get(task, :container_id)) and Map.get(task, :container_id) != "",
        do: [:container_id | fields_to_keep],
        else: fields_to_keep

    fields_to_keep =
      if Map.has_key?(task, :instruction),
        do: [
          :title,
          :image,
          :created_at,
          :started_at,
          :completed_at,
          :session_summary,
          :todo_items | fields_to_keep
        ],
        else: fields_to_keep

    Map.take(session_update, fields_to_keep)
  end

  def derive_container_id(cid, _task_id) when is_binary(cid) and cid != "", do: cid
  def derive_container_id(_cid, task_id) when is_binary(task_id), do: "task:" <> task_id
  def derive_container_id(_cid, _task_id), do: "task:unknown"

  def split_matching_sessions(sessions, task_id, task_container_id) do
    Enum.split_with(sessions, fn session ->
      matches_container?(session, task_container_id) or session.latest_task_id == task_id
    end)
  end

  def matches_container?(session, cid) when is_binary(cid) and cid != "",
    do: session.container_id == cid

  def matches_container?(_session, _cid), do: false

  def sort_sessions_for_sidebar(sessions) do
    Enum.sort_by(sessions, fn session ->
      {running_session?(session), -latest_at_unix(session)}
    end)
  end

  def running_session?(%{latest_status: status}) do
    status in ["pending", "starting", "running", "queued", "awaiting_feedback"]
  end

  def running_session?(_), do: false

  def latest_at_unix(%{latest_at: %DateTime{} = dt}), do: DateTime.to_unix(dt, :microsecond)

  def latest_at_unix(%{latest_at: %NaiveDateTime{} = dt}),
    do: NaiveDateTime.to_gregorian_seconds(dt)

  def latest_at_unix(_), do: 0

  def merge_unassigned_active_tasks(sessions, tasks) do
    unassigned =
      tasks
      |> Enum.filter(&(active_task?(&1) and is_nil(&1.container_id)))
      |> Enum.map(fn task ->
        %{
          container_id: "task:" <> task.id,
          task_count: 1,
          latest_status: task.status,
          latest_task_id: task.id,
          latest_error: task.error,
          title: task.instruction,
          image: task.image,
          latest_at: task.inserted_at,
          created_at: task.inserted_at,
          todo_items: task.todo_items || %{"items" => []}
        }
      end)

    sessions
    |> Kernel.++(unassigned)
    |> sort_sessions_for_sidebar()
  end

  def has_real_container?(%{container_id: container_id}) when is_binary(container_id) do
    container_id != "" and not String.starts_with?(container_id, "task:")
  end

  def has_real_container?(_), do: false

  @doc "Inserts or replaces a task in the tasks_snapshot list by id."
  def upsert_task_snapshot(tasks, nil), do: tasks

  def upsert_task_snapshot(tasks, task) when is_list(tasks) do
    {matches, rest} = Enum.split_with(tasks, &(&1.id == task.id))

    merged =
      case matches do
        [existing | _] -> Map.merge(existing, task)
        [] -> task
      end

    [merged | rest]
  end

  def upsert_task_snapshot(_tasks, task), do: [task]

  def remove_tasks_for_container(tasks, _container_id) when not is_list(tasks), do: tasks

  def remove_tasks_for_container(tasks, container_id) when is_binary(container_id) do
    Enum.reject(tasks, fn task ->
      task_cid = Map.get(task, :container_id)
      task_id = Map.get(task, :id)

      task_cid == container_id or
        (is_binary(task_id) and "task:#{task_id}" == container_id)
    end)
  end

  def update_task_lifecycle_state(tasks, _task_id, _lifecycle_state) when not is_list(tasks),
    do: tasks

  def update_task_lifecycle_state(tasks, task_id, lifecycle_state) do
    Enum.map(tasks, fn
      %{id: ^task_id} = task -> Map.put(task, :lifecycle_state, lifecycle_state)
      task -> task
    end)
  end

  def update_session_lifecycle_state(sessions, _task_id, _lifecycle_state)
      when not is_list(sessions),
      do: sessions

  def update_session_lifecycle_state(sessions, task_id, lifecycle_state) do
    Enum.map(sessions, fn
      %{latest_task_id: ^task_id} = session -> Map.put(session, :lifecycle_state, lifecycle_state)
      session -> session
    end)
  end

  def lifecycle_state_to_string(state) when is_atom(state), do: Atom.to_string(state)
  def lifecycle_state_to_string(state) when is_binary(state), do: state
  def lifecycle_state_to_string(_state), do: "idle"

  def lifecycle_state_for_task_status(task, status) do
    task
    |> Map.put(:status, status)
    |> Map.put(:lifecycle_state, nil)
    |> SessionStateMachine.state_from_task()
    |> lifecycle_state_to_string()
  end

  def update_session_todo_items(sessions, container_id, todo_maps) do
    Enum.map(sessions, fn
      %{container_id: ^container_id} = session ->
        Map.put(session, :todo_items, %{"items" => todo_maps})

      session ->
        session
    end)
  end

  def subscribe_to_active_tasks(tasks) do
    tasks
    |> Enum.filter(&active_task?/1)
    |> Enum.each(&Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{&1.id}"))
  end

  def hydrate_task_for_session(task, user_id) when is_map(task) do
    task_id = Map.get(task, :id)

    complete? =
      is_binary(task_id) and
        (is_binary(Map.get(task, :instruction)) or is_binary(Map.get(task, :container_id)))

    cond do
      complete? ->
        task

      is_binary(task_id) and match?({:ok, _}, Ecto.UUID.cast(task_id)) ->
        case Sessions.get_task(task_id, user_id) do
          {:ok, persisted} -> persisted
          _ -> task
        end

      true ->
        task
    end
  end

  def hydrate_task_for_session(task, _user_id), do: task

  def resolve_new_task_ack_task(task, user_id, optimistic_entry) do
    hydrated = hydrate_task_for_session(task, user_id)

    cond do
      is_binary(Map.get(hydrated, :instruction)) ->
        hydrated

      is_map(optimistic_entry) and is_binary(optimistic_entry[:instruction]) ->
        find_task_by_instruction(user_id, optimistic_entry[:instruction]) || hydrated

      true ->
        hydrated
    end
  end

  def find_task_by_instruction(user_id, instruction) do
    user_id
    |> Sessions.list_tasks()
    |> Enum.filter(&(&1.instruction == instruction))
    |> Enum.sort_by(
      fn task ->
        case task.inserted_at do
          %DateTime{} = dt -> DateTime.to_unix(dt, :microsecond)
          %NaiveDateTime{} = dt -> NaiveDateTime.to_gregorian_seconds(dt)
          _ -> 0
        end
      end,
      :desc
    )
    |> List.first()
  end
end
