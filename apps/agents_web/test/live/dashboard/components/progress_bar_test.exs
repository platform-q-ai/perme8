defmodule AgentsWeb.DashboardLive.Components.ProgressBarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias AgentsWeb.DashboardLive.Components.SessionComponents

  describe "progress_bar/1" do
    test "renders nothing when todo_items is []" do
      html = render_component(&SessionComponents.progress_bar/1, todo_items: [])

      refute html =~ ~s(data-testid="todo-progress")
    end

    test "renders container and summary when todo items exist" do
      html =
        render_component(&SessionComponents.progress_bar/1,
          todo_items: [
            %{id: "todo-1", title: "Plan", status: "completed", position: 0},
            %{id: "todo-2", title: "Build", status: "pending", position: 1}
          ]
        )

      assert html =~ ~s(data-testid="todo-progress")
      assert html =~ ~s(data-testid="todo-progress-summary")
      assert html =~ "1/2 steps complete"
    end

    test "renders numbered step entries with required test ids and tooltip text" do
      html =
        render_component(&SessionComponents.progress_bar/1,
          todo_items: [
            %{id: "todo-1", title: "First step", status: "completed", position: 0},
            %{id: "todo-2", title: "Second step", status: "in_progress", position: 1}
          ]
        )

      assert html =~ ~s(data-testid="todo-step-1")
      assert html =~ ~s(data-testid="todo-step-2")

      # Step text is inside tooltip children; extract text content via Floki
      {:ok, doc} = Floki.parse_document(html)

      step_1_text = doc |> Floki.find(~s([data-testid="todo-step-1"])) |> Floki.text()
      step_2_text = doc |> Floki.find(~s([data-testid="todo-step-2"])) |> Floki.text()

      assert step_1_text =~ "1."
      assert step_1_text =~ "First step"
      assert step_2_text =~ "2."
      assert step_2_text =~ "Second step"
    end

    test "applies status classes is-pending, is-in-progress, is-completed, is-failed" do
      html =
        render_component(&SessionComponents.progress_bar/1,
          todo_items: [
            %{id: "todo-1", title: "Pending", status: "pending", position: 0},
            %{id: "todo-2", title: "In progress", status: "in_progress", position: 1},
            %{id: "todo-3", title: "Completed", status: "completed", position: 2},
            %{id: "todo-4", title: "Failed", status: "failed", position: 3}
          ]
        )

      # Parse HTML and verify each step has the correct status class
      {:ok, doc} = Floki.parse_document(html)

      step_1 = Floki.find(doc, ~s([data-testid="todo-step-1"]))
      step_2 = Floki.find(doc, ~s([data-testid="todo-step-2"]))
      step_3 = Floki.find(doc, ~s([data-testid="todo-step-3"]))
      step_4 = Floki.find(doc, ~s([data-testid="todo-step-4"]))

      assert step_class(step_1) =~ "is-pending"
      assert step_class(step_2) =~ "is-in-progress"
      assert step_class(step_3) =~ "is-completed"
      assert step_class(step_4) =~ "is-failed"
    end

    test "summary uses completed/total format" do
      todo_items =
        Enum.map(0..6, fn index ->
          status = if index < 3, do: "completed", else: "pending"
          %{id: "todo-#{index}", title: "Step #{index + 1}", status: status, position: index}
        end)

      html = render_component(&SessionComponents.progress_bar/1, todo_items: todo_items)

      assert html =~ "3/7 steps complete"
    end
  end

  defp step_class([{_tag, attrs, _children}]) do
    attrs |> Enum.find(fn {k, _} -> k == "class" end) |> elem(1)
  end
end
