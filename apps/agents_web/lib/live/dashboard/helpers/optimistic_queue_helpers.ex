defmodule AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers do
  @moduledoc """
  Optimistic queue and new-session state management for the dashboard LiveView.

  Handles hydration, normalization, merging, broadcasting, and serialization
  of optimistic queue entries and new-session entries that are stored in the
  browser via hooks and synchronized with the server.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_event: 3, put_flash: 3]

  alias Agents.Sessions

  @optimistic_stale_seconds 120

  def normalize_hydrated_queue_entry(entry) when is_map(entry) do
    id = entry["id"] || entry["correlation_key"]
    content = entry["content"]

    if is_binary(id) and is_binary(content) do
      %{
        id: id,
        correlation_key: entry["correlation_key"] || id,
        content: content,
        status: entry["status"] || "pending",
        queued_at: parse_hydrated_datetime(entry["queued_at"])
      }
    else
      nil
    end
  end

  def normalize_hydrated_queue_entry(_), do: nil

  def parse_hydrated_datetime(nil), do: DateTime.utc_now()

  def parse_hydrated_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end

  def parse_hydrated_datetime(_), do: DateTime.utc_now()

  def normalize_hydrated_new_session_entry(entry) when is_map(entry) do
    id = entry["id"]
    instruction = entry["instruction"]

    if is_binary(id) and is_binary(instruction) do
      %{
        id: id,
        instruction: instruction,
        image: entry["image"] || Sessions.default_image(),
        status: entry["status"] || "queued",
        queued_at: parse_hydrated_datetime(entry["queued_at"])
      }
    else
      nil
    end
  end

  def normalize_hydrated_new_session_entry(_), do: nil

  def merge_optimistic_new_sessions(existing, incoming) do
    (existing ++ incoming)
    |> Enum.reduce(%{}, fn entry, acc ->
      case entry[:id] do
        id when is_binary(id) -> Map.put(acc, id, entry)
        _ -> acc
      end
    end)
    |> Map.values()
    |> Enum.sort_by(fn entry ->
      case entry[:queued_at] do
        %DateTime{} = dt -> DateTime.to_unix(dt, :microsecond)
        _ -> 0
      end
    end)
  end

  def remove_optimistic_new_session(entries, client_id) do
    Enum.reject(entries, &(&1.id == client_id))
  end

  def stale_optimistic_entry?(%{queued_at: %DateTime{} = queued_at}) do
    DateTime.diff(DateTime.utc_now(), queued_at, :second) > @optimistic_stale_seconds
  end

  def stale_optimistic_entry?(_), do: true

  def already_has_real_session?(%{instruction: instruction}, sessions)
      when is_binary(instruction) do
    trimmed = String.trim(instruction)
    Enum.any?(sessions, fn session -> String.trim(session.title || "") == trimmed end)
  end

  def already_has_real_session?(_, _), do: false

  def normalize_ordered_ticket_numbers(values) when is_list(values) do
    values
    |> Enum.map(&Integer.parse(to_string(&1)))
    |> Enum.filter(&match?({_, ""}, &1))
    |> Enum.map(fn {n, _} -> n end)
  end

  def normalize_ordered_ticket_numbers(_), do: []

  def merge_queued_messages(existing, incoming) do
    (existing ++ incoming)
    |> Enum.reduce(%{}, fn msg, acc ->
      key = msg[:correlation_key] || msg[:id] || "fallback-#{msg[:content]}"
      Map.put(acc, key, msg)
    end)
    |> Map.values()
    |> Enum.sort_by(fn msg ->
      case msg[:queued_at] do
        %DateTime{} = dt -> DateTime.to_unix(dt, :microsecond)
        _ -> 0
      end
    end)
  end

  def maybe_sync_optimistic_queue_snapshot(socket, previous_queue) do
    current_queue = Map.get(socket.assigns, :queued_messages, [])

    if previous_queue != current_queue do
      broadcast_optimistic_queue_snapshot(socket)
    else
      socket
    end
  end

  def broadcast_optimistic_queue_snapshot(socket) do
    case socket.assigns.current_task do
      %{id: task_id} ->
        payload = %{
          user_id: socket.assigns.current_scope.user.id,
          task_id: task_id,
          entries: serialize_queued_messages(socket.assigns.queued_messages)
        }

        push_event(socket, "optimistic_queue_set", payload)

      _ ->
        socket
    end
  end

  def clear_optimistic_queue_snapshot(socket, task_id) when is_binary(task_id) do
    push_event(socket, "optimistic_queue_clear", %{
      user_id: socket.assigns.current_scope.user.id,
      task_id: task_id
    })
  end

  def clear_optimistic_queue_snapshot(socket, _task_id), do: socket

  def clear_new_task_monitor(socket, client_id) do
    {monitor_ref, _existing} =
      Enum.find(socket.assigns.new_task_monitors, {nil, nil}, fn {_ref, tracked_client_id} ->
        tracked_client_id == client_id
      end)

    if is_reference(monitor_ref) do
      Process.demonitor(monitor_ref, [:flush])

      assign(
        socket,
        :new_task_monitors,
        Map.delete(socket.assigns.new_task_monitors, monitor_ref)
      )
    else
      socket
    end
  end

  def maybe_flash_new_task_down(socket, :normal), do: socket

  def maybe_flash_new_task_down(socket, reason) do
    put_flash(socket, :error, "Session creation failed: #{inspect(reason)}")
  end

  def broadcast_optimistic_new_sessions_snapshot(socket) do
    payload = %{
      user_id: socket.assigns.current_scope.user.id,
      entries: serialize_optimistic_new_sessions(socket.assigns.optimistic_new_sessions)
    }

    push_event(socket, "optimistic_new_sessions_set", payload)
  end

  def serialize_optimistic_new_sessions(entries) do
    Enum.map(entries, fn entry ->
      %{
        id: entry[:id],
        instruction: entry[:instruction],
        image: entry[:image],
        status: entry[:status] || "queued",
        queued_at: serialize_queued_datetime(entry[:queued_at])
      }
    end)
  end

  def serialize_queued_messages(messages) do
    Enum.map(messages, fn msg ->
      %{
        id: msg[:id],
        correlation_key: msg[:correlation_key],
        content: msg[:content],
        status: msg[:status] || "pending",
        queued_at: serialize_queued_datetime(msg[:queued_at])
      }
    end)
  end

  def serialize_queued_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  def serialize_queued_datetime(_), do: DateTime.utc_now() |> DateTime.to_iso8601()
end
