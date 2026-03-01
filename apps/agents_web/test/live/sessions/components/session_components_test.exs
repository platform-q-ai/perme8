defmodule AgentsWeb.SessionsLive.Components.SessionComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias AgentsWeb.SessionsLive.Components.SessionComponents

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
end
