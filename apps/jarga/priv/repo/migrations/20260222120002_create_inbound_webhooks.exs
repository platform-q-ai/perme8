defmodule Jarga.Repo.Migrations.CreateInboundWebhooks do
  use Ecto.Migration

  def change do
    create table(:inbound_webhooks, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:event_type, :string)
      add(:payload, :map)
      add(:source_ip, :string)
      add(:signature_valid, :boolean, null: false, default: false)
      add(:handler_result, :string)
      add(:received_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:inbound_webhooks, [:workspace_id]))
    create(index(:inbound_webhooks, [:workspace_id, :received_at]))
  end
end
