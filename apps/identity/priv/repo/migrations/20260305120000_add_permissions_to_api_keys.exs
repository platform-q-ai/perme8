defmodule Identity.Repo.Migrations.AddPermissionsToApiKeys do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add(:permissions, {:array, :string}, null: true, default: nil)
    end
  end
end
