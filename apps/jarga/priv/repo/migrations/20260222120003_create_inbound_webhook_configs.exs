defmodule Jarga.Repo.Migrations.CreateInboundWebhookConfigs do
  use Ecto.Migration

  def change do
    create table(:inbound_webhook_configs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      # TODO: Encrypt inbound secret at rest (follow-up: add Cloak.Ecto or similar)
      add(:inbound_secret, :string, null: false)

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:inbound_webhook_configs, [:workspace_id]))
  end
end
