defmodule Webhooks.Repo.Migrations.CreateWebhookSubscriptions do
  use Ecto.Migration

  def change do
    create table(:webhook_subscriptions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:url, :string, null: false)
      add(:secret, :string, null: false)
      add(:event_types, {:array, :string}, null: false, default: [])
      add(:is_active, :boolean, null: false, default: true)
      add(:workspace_id, :binary_id, null: false)
      add(:created_by_id, :binary_id)

      timestamps(type: :utc_datetime)
    end

    create(index(:webhook_subscriptions, [:workspace_id]))
    create(index(:webhook_subscriptions, [:workspace_id, :is_active]))
  end
end
