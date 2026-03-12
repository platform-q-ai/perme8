defmodule AgentsWeb.DashboardLive.TaskExecutionHandlers do
  @moduledoc false

  import Phoenix.LiveView, only: [put_flash: 3]
  import AgentsWeb.DashboardLive.SessionDataHelpers
  import AgentsWeb.DashboardLive.Helpers, only: [resumable_task?: 1, last_user_message: 1]

  alias AgentsWeb.DashboardLive.SessionStateMachine

  def run_task(%{"instruction" => instruction} = params, socket) do
    instruction = String.trim(instruction)
    ticket_number = parse_ticket_number_param(params)

    ticket =
      if ticket_number,
        do: find_ticket_by_number(socket.assigns.tickets, ticket_number),
        else: nil

    if instruction == "" do
      {:noreply, put_flash(socket, :error, "Instruction is required")}
    else
      route =
        socket.assigns.current_task
        |> SessionStateMachine.state_from_task()
        |> SessionStateMachine.submission_route()

      # When the submission comes from the ticket tab for a ticket that
      # isn't associated with the current task, force a new task instead
      # of following up on an unrelated running session.
      {route, socket} =
        if route == :follow_up and is_integer(ticket_number) and
             not ticket_owns_current_task?(ticket, socket.assigns.current_task) do
          {:new_or_resume, Phoenix.Component.assign(socket, :composing_new, true)}
        else
          {route, socket}
        end

      route_message_submission(route, socket, instruction, ticket_number, ticket)
    end
  end

  def cancel_task(_params, socket) do
    case socket.assigns.current_task do
      nil -> {:noreply, socket}
      task -> do_cancel_task(task, socket)
    end
  end

  def restart_session(_params, socket) do
    current_task = socket.assigns.current_task

    if resumable_task?(current_task) do
      # Resend the last user message from the chat history so the agent
      # picks up exactly where it left off — no extra "Continue" noise.
      instruction =
        last_user_message(socket.assigns.output_parts) ||
          current_task.instruction

      socket
      |> run_or_resume_task(instruction, nil)
      |> handle_task_result(socket)
    else
      {:noreply, socket}
    end
  end
end
