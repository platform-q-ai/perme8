defmodule WebhooksApi.Repo.Migrations.CreateWebhookDeliveries do
  use Ecto.Migration

  def change do
    create table(:webhook_deliveries, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(
        :subscription_id,
        references(:webhook_subscriptions, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:event_type, :string, null: false)
      add(:payload, :map, null: false, default: %{})
      add(:status, :string, null: false, default: "pending")
      add(:response_code, :integer)
      add(:response_body, :text)
      add(:attempts, :integer, null: false, default: 0)
      add(:max_attempts, :integer, null: false, default: 5)
      add(:next_retry_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:webhook_deliveries, [:subscription_id]))
    create(index(:webhook_deliveries, [:status, :next_retry_at]))
  end
end
