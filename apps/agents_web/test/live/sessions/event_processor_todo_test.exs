defmodule AgentsWeb.SessionsLive.EventProcessorTodoTest do
  use ExUnit.Case, async: true

  alias AgentsWeb.SessionsLive.EventProcessor

  defp base_assigns do
    %{
      session_title: nil,
      session_model: nil,
      session_tokens: nil,
      session_cost: nil,
      session_summary: nil,
      output_parts: [],
      pending_question: nil,
      user_message_ids: MapSet.new(),
      todo_items: []
    }
  end

  defp build_socket(assigns_override \\ %{}) do
    assigns =
      base_assigns()
      |> Map.merge(assigns_override)
      |> Map.put(:__changed__, %{})

    %Phoenix.LiveView.Socket{assigns: assigns}
  end

  describe "process_event/2 with todo.updated" do
    test "updates :todo_items with normalized maps" do
      socket = build_socket()

      event = %{
        "type" => "todo.updated",
        "properties" => %{
          "todos" => [
            %{"id" => "todo-1", "content" => "Plan implementation", "status" => "completed"},
            %{"id" => "todo-2", "content" => "Wire LiveView", "status" => "in_progress"}
          ]
        }
      }

      result = EventProcessor.process_event(event, socket)

      assert result.assigns.todo_items == [
               %{id: "todo-1", title: "Plan implementation", status: "completed", position: 0},
               %{id: "todo-2", title: "Wire LiveView", status: "in_progress", position: 1}
             ]
    end

    test "replaces existing :todo_items on subsequent todo.updated events" do
      socket =
        build_socket(%{
          todo_items: [
            %{id: "old", title: "Old", status: "pending", position: 0}
          ]
        })

      event = %{
        "type" => "todo.updated",
        "properties" => %{
          "todos" => [
            %{"id" => "new-1", "content" => "New todo", "status" => "pending"}
          ]
        }
      }

      result = EventProcessor.process_event(event, socket)

      assert result.assigns.todo_items == [
               %{id: "new-1", title: "New todo", status: "pending", position: 0}
             ]
    end

    test "returns socket unchanged for malformed todo.updated payloads" do
      socket =
        build_socket(%{
          todo_items: [
            %{id: "existing", title: "Keep me", status: "completed", position: 0}
          ]
        })

      malformed = %{"type" => "todo.updated", "properties" => %{"todos" => "not-a-list"}}

      result = EventProcessor.process_event(malformed, socket)

      assert result.assigns.todo_items == socket.assigns.todo_items
    end
  end

  describe "maybe_load_todos/2" do
    test "returns socket unchanged when task is nil" do
      socket =
        build_socket(%{todo_items: [%{id: "a", title: "A", status: "pending", position: 0}]})

      assert EventProcessor.maybe_load_todos(socket, nil).assigns.todo_items ==
               socket.assigns.todo_items
    end

    test "leaves :todo_items as [] when task.todo_items is nil" do
      socket = build_socket()

      task = %{id: "task-1", todo_items: nil}

      result = EventProcessor.maybe_load_todos(socket, task)
      assert result.assigns.todo_items == []
    end

    test "restores :todo_items from persisted %{" <> "\"items\"" <> " => [...]} JSON shape" do
      socket = build_socket()

      task = %{
        id: "task-1",
        todo_items: %{
          "items" => [
            %{"id" => "todo-1", "title" => "Read file", "status" => "completed", "position" => 0},
            %{
              "id" => "todo-2",
              "content" => "Write tests",
              "status" => "in_progress",
              "position" => 1
            }
          ]
        }
      }

      result = EventProcessor.maybe_load_todos(socket, task)

      assert result.assigns.todo_items == [
               %{id: "todo-1", title: "Read file", status: "completed", position: 0},
               %{id: "todo-2", title: "Write tests", status: "in_progress", position: 1}
             ]
    end

    test "restored todo items use atom keys for template access" do
      socket = build_socket()

      task = %{
        id: "task-1",
        todo_items: %{
          "items" => [
            %{"id" => "todo-1", "title" => "First", "status" => "pending", "position" => 0}
          ]
        }
      }

      [item] = EventProcessor.maybe_load_todos(socket, task).assigns.todo_items

      assert item.position == 0
      assert item.status == "pending"
      assert item.id == "todo-1"
      assert item.title == "First"
    end
  end
end
