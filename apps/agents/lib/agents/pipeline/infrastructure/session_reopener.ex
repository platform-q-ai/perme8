defmodule Agents.Pipeline.Infrastructure.SessionReopener do
  @moduledoc "Reopens a coding session by re-queuing the completed task with a follow-up instruction."

  @behaviour Agents.Pipeline.Application.Behaviours.SessionReopenerBehaviour

  alias Agents.Sessions

  @impl true
  def reopen(%{task_id: task_id, user_id: user_id, instruction: instruction}) do
    case Sessions.resume_task(task_id, %{user_id: user_id, instruction: instruction}) do
      {:ok, _task} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
