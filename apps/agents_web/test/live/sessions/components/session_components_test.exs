defmodule AgentsWeb.SessionsLive.Components.SessionComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias AgentsWeb.SessionsLive.Components.SessionComponents
  alias Agents.Sessions.Domain.Entities.Ticket

  describe "status_badge/1" do
    test "renders idle badge" do
      html = render_component(&SessionComponents.status_badge/1, status: "idle")
      assert html =~ "idle"
      assert html =~ "badge-ghost"
    end

    test "renders running badge with pulse animation" do
      html = render_component(&SessionComponents.status_badge/1, status: "running")
      assert html =~ "running"
      assert html =~ "badge-info"
      assert html =~ "animate-pulse"
    end

    test "renders completed badge" do
      html = render_component(&SessionComponents.status_badge/1, status: "completed")
      assert html =~ "completed"
      assert html =~ "badge-success"
    end

    test "renders failed badge" do
      html = render_component(&SessionComponents.status_badge/1, status: "failed")
      assert html =~ "failed"
      assert html =~ "badge-error"
    end

    test "renders pending badge" do
      html = render_component(&SessionComponents.status_badge/1, status: "pending")
      assert html =~ "pending"
      assert html =~ "badge-warning"
    end
  end

  describe "status_dot/1" do
    test "renders success dot for completed status" do
      html = render_component(&SessionComponents.status_dot/1, status: "completed")
      assert html =~ "bg-success"
    end

    test "renders error dot for failed status" do
      html = render_component(&SessionComponents.status_dot/1, status: "failed")
      assert html =~ "bg-error"
    end

    test "renders info dot with pulse for running status" do
      html = render_component(&SessionComponents.status_dot/1, status: "running")
      assert html =~ "bg-info"
      assert html =~ "animate-pulse"
    end

    test "renders warning dot for pending status" do
      html = render_component(&SessionComponents.status_dot/1, status: "pending")
      assert html =~ "bg-warning"
    end

    test "renders muted dot for cancelled status" do
      html = render_component(&SessionComponents.status_dot/1, status: "cancelled")
      assert html =~ "bg-base-content/30"
    end

    test "renders grey dot for cold queued status" do
      html = render_component(&SessionComponents.status_dot/1, status: "queued", cold: true)
      assert html =~ "bg-base-content/35"
    end

    test "renders neutral dot for warm queued status" do
      html = render_component(&SessionComponents.status_dot/1, status: "queued", cold: false)
      assert html =~ "bg-neutral"
      refute html =~ "bg-base-content/35"
    end
  end

  describe "output_part/1 — text variants" do
    test "renders streaming text with cursor animation" do
      html =
        render_component(&SessionComponents.output_part/1,
          part: {:text, "part-1", "Hello streaming", :streaming}
        )

      assert html =~ "Hello streaming"
      assert html =~ "animate-pulse"
      assert html =~ "whitespace-pre-wrap"
    end

    test "renders frozen text as markdown" do
      html =
        render_component(&SessionComponents.output_part/1,
          part: {:text, "part-1", "**bold text**", :frozen}
        )

      assert html =~ "<strong>bold text</strong>"
      assert html =~ "session-markdown"
    end
  end

  describe "output_part/1 — reasoning variants" do
    test "renders streaming reasoning with thinking label" do
      html =
        render_component(&SessionComponents.output_part/1,
          part: {:reasoning, "r-1", "Considering options...", :streaming}
        )

      assert html =~ "Thinking"
      assert html =~ "Considering options..."
      assert html =~ "loading loading-dots"
    end

    test "renders frozen reasoning as collapsible details" do
      html =
        render_component(&SessionComponents.output_part/1,
          part: {:reasoning, "r-1", "Final thoughts", :frozen}
        )

      assert html =~ "Thinking"
      assert html =~ "<details"
    end
  end

  describe "output_part/1 — tool variants" do
    test "renders running tool with spinner" do
      html =
        render_component(&SessionComponents.output_part/1,
          part:
            {:tool, "t-1", "bash", :running,
             %{input: "ls -la", title: nil, output: nil, error: nil}}
        )

      assert html =~ "bash"
      assert html =~ "loading loading-spinner"
    end

    test "renders completed tool with check icon" do
      html =
        render_component(&SessionComponents.output_part/1,
          part:
            {:tool, "t-1", "read", :done,
             %{input: "file.ex", title: nil, output: "contents", error: nil}}
        )

      assert html =~ "read"
      assert html =~ "hero-check-circle"
    end

    test "renders error tool with error icon" do
      html =
        render_component(&SessionComponents.output_part/1,
          part:
            {:tool, "t-1", "write", :error,
             %{input: nil, title: nil, output: nil, error: "Permission denied"}}
        )

      assert html =~ "write"
      assert html =~ "hero-exclamation-circle"
      assert html =~ "Permission denied"
    end
  end

  describe "queued_message/1" do
    test "renders queued message with data-testid" do
      msg = %{id: "q-1", content: "fix the bug", queued_at: ~U[2026-03-01 00:00:00Z]}
      html = render_component(&SessionComponents.queued_message/1, message: msg)
      assert html =~ ~s(data-testid="queued-message-q-1")
    end

    test "renders Queued badge" do
      msg = %{id: "q-1", content: "fix the bug", queued_at: ~U[2026-03-01 00:00:00Z]}
      html = render_component(&SessionComponents.queued_message/1, message: msg)
      assert html =~ "Queued"
      assert html =~ "badge"
    end

    test "renders message content trimmed" do
      msg = %{id: "q-1", content: "  hello world  ", queued_at: ~U[2026-03-01 00:00:00Z]}
      html = render_component(&SessionComponents.queued_message/1, message: msg)
      assert html =~ "hello world"
    end

    test "renders with muted opacity class" do
      msg = %{id: "q-1", content: "fix", queued_at: ~U[2026-03-01 00:00:00Z]}
      html = render_component(&SessionComponents.queued_message/1, message: msg)
      assert html =~ "opacity-60"
    end

    test "renders user avatar icon" do
      msg = %{id: "q-1", content: "fix", queued_at: ~U[2026-03-01 00:00:00Z]}
      html = render_component(&SessionComponents.queued_message/1, message: msg)
      assert html =~ "hero-user"
    end

    test "renders You label" do
      msg = %{id: "q-1", content: "test", queued_at: ~U[2026-03-01 00:00:00Z]}
      html = render_component(&SessionComponents.queued_message/1, message: msg)
      assert html =~ "You"
    end
  end

  describe "chat_part/1 — subtask" do
    test "renders subtask with agent name and description" do
      part =
        {:subtask, "sub-1",
         %{
           agent: "explore",
           description: "Research spike",
           prompt: "Explore the codebase",
           status: :running
         }}

      html = render_component(&SessionComponents.chat_part/1, part: part)
      assert html =~ "explore"
      assert html =~ "Research spike"
      assert html =~ "loading"
    end

    test "done subtask renders with checkmark instead of spinner" do
      part =
        {:subtask, "sub-1",
         %{
           agent: "explore",
           description: "Research spike",
           prompt: "Explore the codebase",
           status: :done
         }}

      html = render_component(&SessionComponents.chat_part/1, part: part)
      assert html =~ "explore"
      refute html =~ "loading loading-spinner"
      assert html =~ "hero-check-circle"
    end

    test "subtask card is collapsible with prompt text in body" do
      part =
        {:subtask, "sub-1",
         %{
           agent: "general",
           description: "Multi-step task",
           prompt: "Implement the feature end-to-end",
           status: :done
         }}

      html = render_component(&SessionComponents.chat_part/1, part: part)
      assert html =~ "<details"
      assert html =~ "Implement the feature end-to-end"
    end
  end

  describe "container_stats_bars/1" do
    test "renders CPU and memory bars" do
      html =
        render_component(&SessionComponents.container_stats_bars/1,
          stats: %{
            cpu_percent: 45.0,
            memory_percent: 60.0,
            memory_usage: 536_870_912,
            memory_limit: 1_073_741_824
          }
        )

      assert html =~ "CPU"
      assert html =~ "MEM"
      assert html =~ "45%"
      assert html =~ "512M"
    end
  end

  describe "ticket_card/1" do
    test "renders data-ticket-depth attribute" do
      ticket = Ticket.new(%{number: 1, title: "Parent"})

      html =
        render_component(&SessionComponents.ticket_card/1,
          ticket: ticket,
          variant: :triage,
          depth: 1
        )

      assert html =~ ~s(data-ticket-depth="1")
    end

    test "applies subticket-card class for depth greater than zero" do
      ticket = Ticket.new(%{number: 2, title: "Child"})

      html =
        render_component(&SessionComponents.ticket_card/1,
          ticket: ticket,
          variant: :triage,
          depth: 1
        )

      assert html =~ "subticket-card"
      assert html =~ "ml-4"
    end

    test "renders sub-issue badge when ticket has sub_tickets" do
      ticket =
        Ticket.new(%{
          number: 3,
          title: "Parent",
          sub_tickets: [Ticket.new(%{number: 31, title: "Child"})]
        })

      html = render_component(&SessionComponents.ticket_card/1, ticket: ticket, variant: :triage)

      assert html =~ "1 sub-issues"
      assert html =~ ~s(data-has-subissues="true")
    end
  end
end
