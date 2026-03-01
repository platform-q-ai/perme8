defmodule Agents.Repo.Migrations.AddTodoItemsToSessionsTasks do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:todo_items, :map, default: nil)
    end
  end
end
