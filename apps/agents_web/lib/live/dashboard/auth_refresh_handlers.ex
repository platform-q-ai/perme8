defmodule AgentsWeb.DashboardLive.AuthRefreshHandlers do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]
  import AgentsWeb.DashboardLive.Helpers, only: [auth_error?: 1, resumable_task?: 1]

  alias Agents.Sessions

  def refresh_auth_and_resume(params, socket) do
    task_id = params["task-id"] || (socket.assigns.current_task && socket.assigns.current_task.id)

    cond do
      is_nil(task_id) ->
        {:noreply, socket}

      Map.has_key?(socket.assigns.auth_refreshing, task_id) ->
        # Already refreshing this session
        {:noreply, socket}

      true ->
        user = socket.assigns.current_scope.user

        async =
          Task.async(fn -> {task_id, Sessions.refresh_auth_and_resume(task_id, user.id)} end)

        {:noreply,
         socket
         |> assign(
           :auth_refreshing,
           Map.put(socket.assigns.auth_refreshing, task_id, async.ref)
         )
         |> put_flash(:info, "Refreshing auth and restarting container...")}
    end
  end

  def refresh_all_auth(_params, socket) do
    user = socket.assigns.current_scope.user
    tasks = Sessions.list_tasks(user.id)

    refreshable =
      Enum.filter(tasks, fn t ->
        t.status == "failed" and auth_error?(t.error) and resumable_task?(t) and
          not Map.has_key?(socket.assigns.auth_refreshing, t.id)
      end)

    socket =
      Enum.reduce(refreshable, socket, fn t, acc ->
        async = Task.async(fn -> {t.id, Sessions.refresh_auth_and_resume(t.id, user.id)} end)
        assign(acc, :auth_refreshing, Map.put(acc.assigns.auth_refreshing, t.id, async.ref))
      end)

    flash_msg =
      case length(refreshable) do
        0 -> "No sessions need auth refresh"
        n -> "Refreshing auth for #{n} session(s)..."
      end

    {:noreply, put_flash(socket, :info, flash_msg)}
  end
end
