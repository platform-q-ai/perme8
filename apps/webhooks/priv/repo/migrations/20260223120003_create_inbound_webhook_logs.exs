defmodule Webhooks.Repo.Migrations.CreateInboundWebhookLogs do
  use Ecto.Migration

  def change do
    create table(:inbound_webhook_logs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:workspace_id, :binary_id, null: false)
      add(:event_type, :string)
      add(:payload, :map, default: %{})
      add(:source_ip, :string)
      add(:signature_valid, :boolean, null: false, default: false)
      add(:handler_result, :string)
      add(:received_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:inbound_webhook_logs, [:workspace_id]))
    create(index(:inbound_webhook_logs, [:workspace_id, :received_at]))
  end
end
