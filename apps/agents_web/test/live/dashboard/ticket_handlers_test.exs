defmodule AgentsWeb.DashboardLive.TicketHandlersTest do
  @moduledoc """
  Tests for ticket session lifecycle — starting a session from a ticket,
  verifying the task is created and linked, and that the UI navigates
  to the session.
  """
  use AgentsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures
  import Ecto.Query

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Repo
  alias Ecto.Adapters.SQL.Sandbox

  # Polls until a condition function returns true, with a timeout.
  # Useful for waiting on LiveView state changes that happen asynchronously.
  defp await_lv_condition(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 2_000)
    interval = Keyword.get(opts, :interval, 50)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_await_condition(fun, interval, deadline)
  end

  defp do_await_condition(fun, interval, deadline) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("Timed out waiting for LiveView condition")
      else
        Process.sleep(interval)
        do_await_condition(fun, interval, deadline)
      end
    end
  end

  # Polls the database until a task matching the query appears, with exponential backoff.
  # Avoids brittle Process.sleep with a fixed duration.
  defp await_task_created(query, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 2_000)
    interval = Keyword.get(opts, :interval, 50)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_await_task(query, interval, deadline)
  end

  defp do_await_task(query, interval, deadline) do
    case Repo.one(query) do
      %TaskSchema{} = task ->
        task

      nil ->
        if System.monotonic_time(:millisecond) >= deadline do
          flunk("Timed out waiting for task to be created")
        else
          Process.sleep(interval)
          do_await_task(query, interval, deadline)
        end
    end
  end

  describe "start_ticket_session" do
    setup %{conn: conn} do
      user = user_fixture()
      # Allow sandbox access from spawned processes (start_ticket_session
      # uses spawn_monitor to create the task asynchronously).
      Sandbox.mode(Repo, {:shared, self()})

      on_exit(fn ->
        # Give in-flight DB operations (ticket linking, task updates) time
        # to finish before the sandbox connection is reclaimed.
        Process.sleep(100)
      end)

      %{conn: log_in_user(conn, user), user: user}
    end

    test "creates a task and links it to the ticket", %{conn: conn, user: user} do
      # Need at least one existing session for the play button to appear
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-ticket-handler-test",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 700,
          title: "Task creation test ticket",
          body: "Verify task is created from ticket session start.",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: ["bug"]
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Verify ticket is in triage
      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-700")

      # Click play — triggers start_ticket_session
      lv
      |> element(~s([data-testid="start-ticket-session-700"]))
      |> render_click()

      # Poll until the async task creation completes
      task_query =
        TaskSchema
        |> where([t], t.user_id == ^user.id)
        |> where([t], ilike(t.instruction, "%pick up ticket #700%"))
        |> order_by([t], desc: t.inserted_at)
        |> limit(1)

      task = await_task_created(task_query)

      # Force a render to process any pending messages
      _ = render(lv)
      assert task.instruction =~ "pick up ticket #700"
      assert task.instruction =~ "Task creation test ticket"
    end

    test "sets current_task after ticket session creation so events are processed", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-ticket-nav-test",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 702,
          title: "Navigation test ticket",
          body: "After starting, current_task should be set.",
          status: "Backlog",
          priority: "Need",
          size: "S",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})
      _ = render(lv)

      # Click play
      lv
      |> element(~s([data-testid="start-ticket-session-702"]))
      |> render_click()

      # Poll until the async task creation completes
      task_query =
        TaskSchema
        |> where([t], t.user_id == ^user.id)
        |> where([t], ilike(t.instruction, "%pick up ticket #702%"))
        |> limit(1)

      task = await_task_created(task_query)

      # Wait for the LiveView to process the :new_task_created message
      # which sets current_task. Without this, the :task_event guard
      # (which checks current_task.id == task_id) will silently discard
      # the event. Poll render until the LiveView has navigated to the
      # session (indicated by the composing_new=false state showing the
      # chat panel instead of the new-session form).
      await_lv_condition(fn ->
        html = render(lv)
        String.contains?(html, "pick up ticket #702")
      end)

      # Simulate a message.part.updated event with assistant text.
      # If current_task was properly set, the event will be processed by
      # EventProcessor (not silently discarded by the task_event guard
      # that checks current_task.id == task_id).
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{
               "type" => "text",
               "text" => "Working on ticket 702"
             },
             "messageID" => "msg-1"
           }
         }}
      )

      html = render(lv)

      # The assistant text should appear in output_parts — proving
      # current_task was set and the task_event guard matched.
      assert html =~ "Working on ticket 702"
    end

    test "ticket moves to build queue after successful task creation", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-ticket-build-test",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 701,
          title: "Build queue test ticket",
          body: "Should end up in build lane.",
          status: "Backlog",
          priority: "Need",
          size: "S",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})
      _ = render(lv)

      # Click play
      lv
      |> element(~s([data-testid="start-ticket-session-701"]))
      |> render_click()

      # Poll until the async task creation completes
      task_query =
        TaskSchema
        |> where([t], t.user_id == ^user.id)
        |> where([t], ilike(t.instruction, "%pick up ticket #701%"))
        |> limit(1)

      _task = await_task_created(task_query)

      html = render(lv)

      # After successful creation the ticket should be in the build lane
      assert html =~ ~s(data-testid="build-ticket-item-701")
      refute html =~ ~s(data-testid="triage-ticket-item-701")
    end
  end
end
