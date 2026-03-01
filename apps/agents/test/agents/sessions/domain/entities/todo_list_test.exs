defmodule Agents.Sessions.Domain.Entities.TodoListTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.{TodoItem, TodoList}

  describe "new/1" do
    test "creates a todo list with todo item structs" do
      items = [%TodoItem{id: "todo-1", title: "Plan", status: "pending", position: 0}]

      todo_list = TodoList.new(%{items: items})

      assert %TodoList{} = todo_list
      assert todo_list.items == items
    end
  end

  describe "from_sse_event/1" do
    test "parses todo.updated payload into a todo list" do
      payload = %{
        "type" => "todo.updated",
        "properties" => %{
          "todos" => [
            %{"id" => "todo-1", "content" => "Plan", "status" => "completed"},
            %{"id" => "todo-2", "content" => "Build", "status" => "in_progress"}
          ]
        }
      }

      assert {:ok, %TodoList{} = todo_list} = TodoList.from_sse_event(payload)
      assert length(todo_list.items) == 2

      assert Enum.at(todo_list.items, 0) ==
               %TodoItem{id: "todo-1", title: "Plan", status: "completed", position: 0}

      assert Enum.at(todo_list.items, 1) ==
               %TodoItem{id: "todo-2", title: "Build", status: "in_progress", position: 1}
    end

    test "returns error for malformed payload" do
      assert {:error, :invalid_payload} = TodoList.from_sse_event(%{})
      assert {:error, :invalid_payload} = TodoList.from_sse_event(%{"type" => "todo.updated"})

      assert {:error, :invalid_payload} =
               TodoList.from_sse_event(%{"properties" => %{"todos" => "not-a-list"}})
    end

    test "assigns position from list order" do
      payload = %{
        "properties" => %{
          "todos" => [
            %{"id" => "todo-a", "content" => "First", "status" => "pending"},
            %{"id" => "todo-b", "content" => "Second", "status" => "pending"},
            %{"id" => "todo-c", "content" => "Third", "status" => "pending"}
          ]
        }
      }

      assert {:ok, %TodoList{items: items}} = TodoList.from_sse_event(payload)

      assert Enum.map(items, & &1.position) == [0, 1, 2]
    end
  end

  describe "progress helpers" do
    test "progress_percentage/1 calculates completed percentage" do
      todo_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "1", title: "A", status: "completed", position: 0},
            %TodoItem{id: "2", title: "B", status: "completed", position: 1},
            %TodoItem{id: "3", title: "C", status: "pending", position: 2},
            %TodoItem{id: "4", title: "D", status: "pending", position: 3}
          ]
        })

      assert TodoList.progress_percentage(todo_list) == 50.0
    end

    test "progress_percentage/1 returns 0.0 for empty list" do
      assert TodoList.progress_percentage(%TodoList{items: []}) == 0.0
    end

    test "completed_count/1 returns count of completed items" do
      todo_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "1", title: "A", status: "completed", position: 0},
            %TodoItem{id: "2", title: "B", status: "in_progress", position: 1},
            %TodoItem{id: "3", title: "C", status: "completed", position: 2}
          ]
        })

      assert TodoList.completed_count(todo_list) == 2
    end

    test "total_count/1 returns total item count" do
      todo_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "1", title: "A", status: "completed", position: 0},
            %TodoItem{id: "2", title: "B", status: "pending", position: 1}
          ]
        })

      assert TodoList.total_count(todo_list) == 2
    end

    test "progress_summary/1 returns completed/total summary" do
      todo_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "1", title: "A", status: "completed", position: 0},
            %TodoItem{id: "2", title: "B", status: "completed", position: 1},
            %TodoItem{id: "3", title: "C", status: "pending", position: 2}
          ]
        })

      assert TodoList.progress_summary(todo_list) == "2/3 steps complete"
    end
  end

  describe "current_step/1" do
    test "returns first in_progress item" do
      todo_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "1", title: "A", status: "completed", position: 0},
            %TodoItem{id: "2", title: "B", status: "in_progress", position: 1},
            %TodoItem{id: "3", title: "C", status: "pending", position: 2}
          ]
        })

      assert %TodoItem{id: "2"} = TodoList.current_step(todo_list)
    end

    test "returns first pending item when none in progress" do
      todo_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "1", title: "A", status: "completed", position: 0},
            %TodoItem{id: "2", title: "B", status: "pending", position: 1},
            %TodoItem{id: "3", title: "C", status: "pending", position: 2}
          ]
        })

      assert %TodoItem{id: "2"} = TodoList.current_step(todo_list)
    end

    test "returns nil for empty list" do
      assert TodoList.current_step(%TodoList{items: []}) == nil
    end
  end

  describe "all_completed?/1" do
    test "returns true only when all items are completed" do
      completed_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "1", title: "A", status: "completed", position: 0},
            %TodoItem{id: "2", title: "B", status: "completed", position: 1}
          ]
        })

      incomplete_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "1", title: "A", status: "completed", position: 0},
            %TodoItem{id: "2", title: "B", status: "pending", position: 1}
          ]
        })

      assert TodoList.all_completed?(completed_list)
      refute TodoList.all_completed?(incomplete_list)
      refute TodoList.all_completed?(%TodoList{items: []})
    end
  end

  describe "to_maps/1 and from_maps/1" do
    test "serializes todo items to plain maps" do
      todo_list =
        TodoList.new(%{
          items: [
            %TodoItem{id: "todo-1", title: "Plan", status: "completed", position: 0},
            %TodoItem{id: "todo-2", title: "Build", status: "pending", position: 1}
          ]
        })

      assert TodoList.to_maps(todo_list) == [
               %{"id" => "todo-1", "title" => "Plan", "status" => "completed", "position" => 0},
               %{"id" => "todo-2", "title" => "Build", "status" => "pending", "position" => 1}
             ]
    end

    test "deserializes plain maps to todo items" do
      maps = [
        %{"id" => "todo-1", "title" => "Plan", "status" => "completed", "position" => 0},
        %{"id" => "todo-2", "title" => "Build", "status" => "pending", "position" => 1}
      ]

      assert %TodoList{items: [%TodoItem{id: "todo-1"}, %TodoItem{id: "todo-2"}]} =
               TodoList.from_maps(maps)
    end
  end
end
