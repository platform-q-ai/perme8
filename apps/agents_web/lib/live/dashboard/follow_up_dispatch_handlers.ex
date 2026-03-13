defmodule AgentsWeb.DashboardLive.FollowUpDispatchHandlers do
  @moduledoc "Routes follow-up messages to existing tasks or creates new ones."

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]
  import AgentsWeb.DashboardLive.SessionDataHelpers

  alias Agents.Sessions
  alias AgentsWeb.DashboardLive.SessionStateMachine

  require Logger

  @follow_up_timeout_ms 30_000

  def dispatch_follow_up_message(task_id, instruction, correlation_key, queued_at, socket) do
    caller = self()
    timeout_ref = make_ref()

    Task.start(fn ->
      try do
        result =
          Sessions.send_message(
            task_id,
            instruction,
            correlation_key: correlation_key,
            command_type: "follow_up_message",
            sent_at: DateTime.to_iso8601(queued_at)
          )

        send(caller, {:follow_up_send_result, correlation_key, result})
      rescue
        error ->
          send(caller, {:follow_up_send_result, correlation_key, {:error, error}})
      end
    end)

    Process.send_after(
      self(),
      {:follow_up_timeout, correlation_key, timeout_ref},
      @follow_up_timeout_ms
    )

    pending =
      Map.put(socket.assigns.pending_follow_ups, correlation_key, %{
        ref: timeout_ref,
        dispatched_at: DateTime.utc_now()
      })

    {:noreply, assign(socket, :pending_follow_ups, pending)}
  end

  def follow_up_send_result(correlation_key, :ok, socket) do
    {:noreply,
     assign(
       socket,
       :pending_follow_ups,
       Map.delete(socket.assigns.pending_follow_ups, correlation_key)
     )}
  end

  def follow_up_send_result(correlation_key, {:error, _reason}, socket) do
    {:noreply,
     socket
     |> assign(
       :pending_follow_ups,
       Map.delete(socket.assigns.pending_follow_ups, correlation_key)
     )
     |> assign(
       :queued_messages,
       SessionStateMachine.mark_queued_message_status(
         socket.assigns.queued_messages,
         correlation_key,
         "rolled_back"
       )
     )
     |> broadcast_optimistic_queue_snapshot()
     |> put_flash(:error, "Failed to send message")}
  end

  def follow_up_timeout(correlation_key, timeout_ref, socket) do
    case Map.get(socket.assigns.pending_follow_ups, correlation_key) do
      %{ref: ^timeout_ref} ->
        Logger.warning("Follow-up dispatch timed out for correlation_key=#{correlation_key}")

        {:noreply,
         socket
         |> assign(
           :pending_follow_ups,
           Map.delete(socket.assigns.pending_follow_ups, correlation_key)
         )
         |> assign(
           :queued_messages,
           SessionStateMachine.mark_queued_message_status(
             socket.assigns.queued_messages,
             correlation_key,
             "timed_out"
           )
         )
         |> broadcast_optimistic_queue_snapshot()}

      _ ->
        # Already resolved (success or error arrived before timeout) — ignore
        {:noreply, socket}
    end
  end
end
