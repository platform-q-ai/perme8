defmodule Notifications.Infrastructure.Subscribers.TaskCompletionSubscriber do
  @moduledoc """
  EventHandler that reacts to task terminal events and creates notifications.
  """

  use Perme8.Events.EventHandler

  @create_notification_use_case Notifications.Application.UseCases.CreateNotification

  @impl Perme8.Events.EventHandler
  def subscriptions, do: ["events:sessions:task"]

  @impl Perme8.Events.EventHandler
  def handle_event(%{event_type: "sessions.task_completed"} = event) do
    create_task_notification(event, "task_completed", "Task completed", nil)
  end

  def handle_event(%{event_type: "sessions.task_failed"} = event) do
    create_task_notification(event, "task_failed", "Task failed", event.error)
  end

  def handle_event(%{event_type: "sessions.task_cancelled"} = event) do
    create_task_notification(event, "task_cancelled", "Task cancelled", nil)
  end

  @impl Perme8.Events.EventHandler
  def handle_event(_event), do: :ok

  defp create_task_notification(
         %{target_user_id: user_id} = event,
         type,
         title,
         error
       )
       when is_binary(user_id) and user_id != "" do
    instruction = truncate_instruction(event.instruction)

    data =
      %{
        "task_id" => event.task_id,
        "instruction" => instruction
      }
      |> maybe_put_error(error)

    body =
      case error do
        value when is_binary(value) and value != "" ->
          "#{instruction} (Error: #{value})"

        _ ->
          instruction
      end

    params = %{
      user_id: user_id,
      type: type,
      title: title,
      body: body,
      data: data
    }

    case @create_notification_use_case.execute(params) do
      {:ok, _notification} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_task_notification(_event, _type, _title, _error), do: :ok

  defp maybe_put_error(data, value) when is_binary(value) and value != "" do
    Map.put(data, "error", value)
  end

  defp maybe_put_error(data, _value), do: data

  defp truncate_instruction(nil), do: "Task finished"

  defp truncate_instruction(instruction) when is_binary(instruction) do
    case String.trim(instruction) do
      "" ->
        "Task finished"

      text ->
        if String.length(text) <= 140 do
          text
        else
          String.slice(text, 0, 137) <> "..."
        end
    end
  end

  defp truncate_instruction(_), do: "Task finished"
end
