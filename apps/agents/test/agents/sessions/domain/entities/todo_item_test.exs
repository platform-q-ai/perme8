defmodule Agents.Sessions.Domain.Entities.TodoItemTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.TodoItem

  describe "new/1" do
    test "creates a todo item with required fields" do
      attrs = %{id: "todo-1", title: "Write tests", position: 0, status: "in_progress"}

      todo_item = TodoItem.new(attrs)

      assert %TodoItem{} = todo_item
      assert todo_item.id == "todo-1"
      assert todo_item.title == "Write tests"
      assert todo_item.position == 0
      assert todo_item.status == "in_progress"
    end

    test "defaults status to pending" do
      todo_item = TodoItem.new(%{id: "todo-2", title: "Run tests", position: 1})

      assert todo_item.status == "pending"
    end
  end

  describe "valid_statuses/0" do
    test "returns valid todo statuses" do
      assert TodoItem.valid_statuses() == ["pending", "in_progress", "completed", "failed"]
    end
  end

  describe "completed?/1" do
    test "returns true only for completed status" do
      assert TodoItem.completed?(%TodoItem{status: "completed"})
      refute TodoItem.completed?(%TodoItem{status: "pending"})
      refute TodoItem.completed?(%TodoItem{status: "in_progress"})
      refute TodoItem.completed?(%TodoItem{status: "failed"})
    end
  end

  describe "terminal?/1" do
    test "returns true for completed and failed" do
      assert TodoItem.terminal?(%TodoItem{status: "completed"})
      assert TodoItem.terminal?(%TodoItem{status: "failed"})
      refute TodoItem.terminal?(%TodoItem{status: "pending"})
      refute TodoItem.terminal?(%TodoItem{status: "in_progress"})
    end
  end

  describe "from_map/1" do
    test "converts string-key map to todo item" do
      map = %{
        "id" => "todo-3",
        "title" => "Plan implementation",
        "status" => "completed",
        "position" => 2
      }

      todo_item = TodoItem.from_map(map)

      assert %TodoItem{} = todo_item
      assert todo_item.id == "todo-3"
      assert todo_item.title == "Plan implementation"
      assert todo_item.status == "completed"
      assert todo_item.position == 2
    end

    test "handles missing keys with defaults" do
      todo_item = TodoItem.from_map(%{})

      assert %TodoItem{} = todo_item
      assert todo_item.id == ""
      assert todo_item.title == ""
      assert todo_item.status == "pending"
      assert todo_item.position == 0
    end
  end

  describe "to_map/1" do
    test "serializes todo item to plain map" do
      todo_item = %TodoItem{id: "todo-4", title: "Refactor", status: "failed", position: 3}

      assert TodoItem.to_map(todo_item) == %{
               "id" => "todo-4",
               "title" => "Refactor",
               "status" => "failed",
               "position" => 3
             }
    end
  end
end
