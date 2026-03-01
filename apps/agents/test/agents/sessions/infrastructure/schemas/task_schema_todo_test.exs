defmodule Agents.Sessions.Infrastructure.Schemas.TaskSchemaTodoTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  import Agents.Test.AccountsFixtures

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  describe "status_changeset/2 todo_items" do
    test "accepts a todo_items map field", %{user: user} do
      {:ok, task} =
        %TaskSchema{}
        |> TaskSchema.changeset(%{instruction: "Run task", user_id: user.id})
        |> Repo.insert()

      todo_items = %{
        "items" => [
          %{"id" => "todo-1", "title" => "Plan", "status" => "pending", "position" => 0}
        ]
      }

      changeset = TaskSchema.status_changeset(task, %{status: "running", todo_items: todo_items})

      assert changeset.valid?
      assert get_change(changeset, :todo_items) == todo_items
    end

    test "stores list-of-maps in todo_items", %{user: user} do
      {:ok, task} =
        %TaskSchema{}
        |> TaskSchema.changeset(%{instruction: "Run task", user_id: user.id})
        |> Repo.insert()

      todo_items = %{
        "items" => [
          %{"id" => "todo-1", "title" => "Plan", "status" => "completed", "position" => 0},
          %{"id" => "todo-2", "title" => "Code", "status" => "in_progress", "position" => 1}
        ]
      }

      assert {:ok, updated} =
               task
               |> TaskSchema.status_changeset(%{status: "running", todo_items: todo_items})
               |> Repo.update()

      assert updated.todo_items == todo_items
      assert [%{"id" => "todo-1"}, %{"id" => "todo-2"}] = updated.todo_items["items"]
    end

    test "accepts nil for todo_items", %{user: user} do
      {:ok, task} =
        %TaskSchema{}
        |> TaskSchema.changeset(%{instruction: "Run task", user_id: user.id})
        |> Repo.insert()

      changeset = TaskSchema.status_changeset(task, %{status: "running", todo_items: nil})

      assert changeset.valid?
      assert get_change(changeset, :todo_items) == nil
    end
  end

  describe "changeset/2 todo_items immutability" do
    test "does not accept todo_items on creation", %{user: user} do
      todo_items = %{
        "items" => [
          %{"id" => "todo-1", "title" => "Plan", "status" => "pending", "position" => 0}
        ]
      }

      changeset =
        TaskSchema.changeset(%TaskSchema{}, %{
          instruction: "Run task",
          user_id: user.id,
          todo_items: todo_items
        })

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :todo_items)
    end
  end
end
