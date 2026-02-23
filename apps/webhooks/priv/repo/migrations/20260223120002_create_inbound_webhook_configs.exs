defmodule Webhooks.Repo.Migrations.CreateInboundWebhookConfigs do
  use Ecto.Migration

  def change do
    create table(:inbound_webhook_configs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:workspace_id, :binary_id, null: false)
      add(:secret, :string, null: false)
      add(:is_active, :boolean, null: false, default: true)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:inbound_webhook_configs, [:workspace_id]))
  end
end
