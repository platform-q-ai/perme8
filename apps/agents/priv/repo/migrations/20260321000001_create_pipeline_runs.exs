defmodule Agents.Repo.Migrations.CreatePipelineRuns do
  use Ecto.Migration

  def change do
    create table(:pipeline_runs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:trigger_type, :string, null: false)
      add(:trigger_reference, :string, null: false)
      add(:task_id, :binary_id)
      add(:session_id, :binary_id)
      add(:pull_request_number, :integer)
      add(:status, :string, null: false, default: "idle")
      add(:current_stage_id, :string)
      add(:remaining_stage_ids, {:array, :string}, null: false, default: [])
      add(:stage_results, :map, null: false, default: %{})
      add(:failure_reason, :text)
      add(:reopened_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:pipeline_runs, [:trigger_type, :trigger_reference]))
    create(index(:pipeline_runs, [:task_id]))
    create(index(:pipeline_runs, [:session_id]))
    create(index(:pipeline_runs, [:pull_request_number]))
    create(index(:pipeline_runs, [:status]))
  end
end
