defmodule Agents.Repo.Migrations.AddAttemptTrackingToPipelineRuns do
  use Ecto.Migration

  def change do
    alter table(:pipeline_runs) do
      add(:attempt_count, :integer, null: false, default: 0)
      add(:stage_attempt_counts, :map, null: false, default: %{})
      add(:visited_stage_ids, {:array, :string}, null: false, default: [])
    end
  end
end
