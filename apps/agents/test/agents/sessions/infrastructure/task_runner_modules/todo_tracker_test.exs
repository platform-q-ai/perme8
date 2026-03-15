defmodule Agents.Sessions.Infrastructure.TaskRunner.TodoTrackerTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.TaskRunner.TodoTracker

  describe "parse_event/1" do
    test "returns {:ok, items} for valid todo.updated properties" do
      properties = %{
        "todos" => [
          %{"id" => "1", "content" => "Do thing", "status" => "pending", "priority" => "high"}
        ]
      }

      assert {:ok, items} = TodoTracker.parse_event(properties)
      assert is_list(items)
      assert length(items) == 1
      assert hd(items)["id"] == "1"
    end

    test "returns {:error, _} for malformed payload" do
      assert {:error, _} = TodoTracker.parse_event(%{})
    end

    test "returns {:error, :invalid_payload} for non-map input" do
      assert {:error, :invalid_payload} = TodoTracker.parse_event(nil)
      assert {:error, :invalid_payload} = TodoTracker.parse_event("string")
    end
  end

  describe "merge_prior_items/2" do
    test "returns current items when no prior items" do
      current = [%{"id" => "1", "content" => "A", "position" => 0}]
      assert TodoTracker.merge_prior_items([], current) == current
    end

    test "prepends unique prior items and shifts positions" do
      prior = [%{"id" => "p1", "content" => "Prior", "position" => 0}]
      current = [%{"id" => "c1", "content" => "Current", "position" => 0}]

      result = TodoTracker.merge_prior_items(prior, current)
      assert length(result) == 2
      assert hd(result)["id"] == "p1"
      assert List.last(result)["id"] == "c1"
      assert List.last(result)["position"] == 1
    end

    test "deduplicates shared IDs — current wins, prior dropped" do
      prior = [%{"id" => "shared", "content" => "Old", "position" => 0}]
      current = [%{"id" => "shared", "content" => "New", "position" => 0}]

      result = TodoTracker.merge_prior_items(prior, current)
      assert length(result) == 1
      assert hd(result)["content"] == "New"
    end

    test "handles multiple prior items with some overlapping" do
      prior = [
        %{"id" => "p1", "content" => "Prior 1", "position" => 0},
        %{"id" => "shared", "content" => "Old shared", "position" => 1}
      ]

      current = [
        %{"id" => "shared", "content" => "New shared", "position" => 0},
        %{"id" => "c1", "content" => "Current 1", "position" => 1}
      ]

      result = TodoTracker.merge_prior_items(prior, current)
      assert length(result) == 3

      # Prior non-overlapping item first
      assert hd(result)["id"] == "p1"
      # Current items with shifted positions
      assert Enum.at(result, 1)["position"] == 1
      assert Enum.at(result, 2)["position"] == 2
    end
  end

  describe "put_attrs/2" do
    test "returns attrs unchanged when todo_items is empty list" do
      attrs = %{status: "completed"}
      assert TodoTracker.put_attrs(attrs, []) == attrs
    end

    test "adds todo_items to attrs when non-empty" do
      items = [%{"id" => "1", "content" => "Thing"}]
      result = TodoTracker.put_attrs(%{status: "completed"}, items)
      assert result == %{status: "completed", todo_items: %{"items" => items}}
    end
  end

  describe "restore_items/1" do
    test "returns items from %{\"items\" => [...]} format" do
      items = [%{"id" => "1", "content" => "Thing"}]
      assert TodoTracker.restore_items(%{"items" => items}) == items
    end

    test "returns empty list for nil" do
      assert TodoTracker.restore_items(nil) == []
    end

    test "returns empty list for invalid input" do
      assert TodoTracker.restore_items(%{}) == []
      assert TodoTracker.restore_items("string") == []
    end
  end
end
