defmodule Agents.Repo.Migrations.CreateInternalPullRequestTables do
  use Ecto.Migration

  def change do
    create table(:pull_requests, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:number, :integer, null: false)
      add(:source_branch, :string, null: false)
      add(:target_branch, :string, null: false)
      add(:title, :string, null: false)
      add(:body, :text)
      add(:status, :string, null: false, default: "draft")
      add(:linked_ticket, :integer)
      add(:merged_at, :utc_datetime)
      add(:closed_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:pull_requests, [:number]))
    create(index(:pull_requests, [:status]))
    create(index(:pull_requests, [:linked_ticket]))

    create table(:pr_comments, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:pull_request_id, references(:pull_requests, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:author_id, :string, null: false)
      add(:body, :text, null: false)
      add(:path, :string)
      add(:line, :integer)

      timestamps(type: :utc_datetime)
    end

    create(index(:pr_comments, [:pull_request_id]))

    create table(:pr_reviews, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:pull_request_id, references(:pull_requests, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:author_id, :string, null: false)
      add(:event, :string, null: false)
      add(:body, :text)
      add(:submitted_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:pr_reviews, [:pull_request_id]))
    create(index(:pr_reviews, [:event]))
  end
end
