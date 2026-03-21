defmodule Agents.Repo.Migrations.AddThreadingFieldsToPrComments do
  use Ecto.Migration

  def change do
    alter table(:pr_comments) do
      add(:parent_comment_id, references(:pr_comments, type: :uuid, on_delete: :nilify_all))
      add(:resolved, :boolean, null: false, default: false)
      add(:resolved_at, :utc_datetime)
      add(:resolved_by, :string)
    end

    create(index(:pr_comments, [:parent_comment_id]))
    create(index(:pr_comments, [:resolved]))
  end
end
