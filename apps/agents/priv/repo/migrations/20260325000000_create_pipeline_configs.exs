defmodule Agents.Repo.Migrations.CreatePipelineConfigs do
  use Ecto.Migration

  def change do
    create table(:pipeline_configs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:slug, :string, null: false)
      add(:version, :integer, null: false)
      add(:name, :string, null: false)
      add(:description, :text)
      add(:merge_queue, :map, null: false, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:pipeline_configs, [:slug]))

    create table(:pipeline_stages, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(
        :pipeline_config_id,
        references(:pipeline_configs, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:position, :integer, null: false)
      add(:stage_id, :string, null: false)
      add(:type, :string, null: false)
      add(:schedule, :map)
      add(:triggers, {:array, :string}, null: false, default: [])
      add(:depends_on, {:array, :string}, null: false, default: [])
      add(:ticket_concurrency, :integer)
      add(:config, :map, null: false, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(index(:pipeline_stages, [:pipeline_config_id, :position]))

    create table(:pipeline_steps, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(
        :pipeline_stage_id,
        references(:pipeline_stages, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:position, :integer, null: false)
      add(:name, :string, null: false)
      add(:run, :text, null: false)
      add(:timeout_seconds, :integer)
      add(:retries, :integer, null: false, default: 0)
      add(:conditions, :text)
      add(:env, :map, null: false, default: %{})
      add(:depends_on, {:array, :string}, null: false, default: [])

      timestamps(type: :utc_datetime)
    end

    create(index(:pipeline_steps, [:pipeline_stage_id, :position]))

    create table(:pipeline_gates, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(
        :pipeline_stage_id,
        references(:pipeline_stages, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:position, :integer, null: false)
      add(:type, :string, null: false)
      add(:required, :boolean, null: false, default: true)
      add(:params, :map, null: false, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(index(:pipeline_gates, [:pipeline_stage_id, :position]))

    execute(&seed_default_pipeline/0, &delete_default_pipeline/0)
  end

  defp seed_default_pipeline do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    pipeline_id = uuid()
    warm_pool_stage_id = uuid()
    test_stage_id = uuid()
    deploy_stage_id = uuid()

    repo().insert_all("pipeline_configs", [
      %{
        id: pipeline_id,
        slug: "current",
        version: 1,
        name: "perme8-core",
        description: "Core CI/CD and runtime warm-pool orchestration pipeline.",
        merge_queue: %{
          "strategy" => "merge_queue",
          "required_stages" => ["test"],
          "required_review" => true,
          "pre_merge_validation" => %{
            "strategy" => "re_run_required_stages",
            "use_existing_container" => true
          }
        },
        inserted_at: now,
        updated_at: now
      }
    ])

    repo().insert_all("pipeline_stages", [
      %{
        id: warm_pool_stage_id,
        pipeline_config_id: pipeline_id,
        position: 0,
        stage_id: "warm-pool",
        type: "warm_pool",
        schedule: %{"cron" => "*/5 * * * *"},
        triggers: ["on_ticket_play", "on_warm_pool"],
        depends_on: [],
        ticket_concurrency: 1,
        config: %{
          "warm_pool" => %{
            "target_count" => 2,
            "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
            "readiness" => %{
              "strategy" => "command_success",
              "required_step" => "prewarm-session-pool"
            }
          }
        },
        inserted_at: now,
        updated_at: now
      },
      %{
        id: test_stage_id,
        pipeline_config_id: pipeline_id,
        position: 1,
        stage_id: "test",
        type: "verification",
        schedule: nil,
        triggers: [],
        depends_on: ["warm-pool"],
        ticket_concurrency: 1,
        config: %{},
        inserted_at: now,
        updated_at: now
      },
      %{
        id: deploy_stage_id,
        pipeline_config_id: pipeline_id,
        position: 2,
        stage_id: "deploy",
        type: "automation",
        schedule: nil,
        triggers: [],
        depends_on: ["test"],
        ticket_concurrency: 1,
        config: %{},
        inserted_at: now,
        updated_at: now
      }
    ])

    repo().insert_all("pipeline_steps", [
      %{
        id: uuid(),
        pipeline_stage_id: warm_pool_stage_id,
        position: 0,
        name: "build-runtime-image",
        run: "mix release",
        timeout_seconds: 900,
        retries: 1,
        conditions: nil,
        env: %{},
        depends_on: [],
        inserted_at: now,
        updated_at: now
      },
      %{
        id: uuid(),
        pipeline_stage_id: warm_pool_stage_id,
        position: 1,
        name: "prewarm-session-pool",
        run: "scripts/warm_pool.sh",
        timeout_seconds: 600,
        retries: 0,
        conditions: nil,
        env: %{},
        depends_on: ["build-runtime-image"],
        inserted_at: now,
        updated_at: now
      },
      %{
        id: uuid(),
        pipeline_stage_id: test_stage_id,
        position: 0,
        name: "unit-tests",
        run: "mix test",
        timeout_seconds: 900,
        retries: 0,
        conditions: nil,
        env: %{},
        depends_on: [],
        inserted_at: now,
        updated_at: now
      },
      %{
        id: uuid(),
        pipeline_stage_id: test_stage_id,
        position: 1,
        name: "boundary-check",
        run: "mix boundary",
        timeout_seconds: 300,
        retries: 0,
        conditions: nil,
        env: %{},
        depends_on: ["unit-tests"],
        inserted_at: now,
        updated_at: now
      },
      %{
        id: uuid(),
        pipeline_stage_id: deploy_stage_id,
        position: 0,
        name: "deploy",
        run: "scripts/deploy.sh",
        timeout_seconds: 1200,
        retries: 0,
        conditions: nil,
        env: %{},
        depends_on: [],
        inserted_at: now,
        updated_at: now
      }
    ])

    repo().insert_all("pipeline_gates", [
      %{
        id: uuid(),
        pipeline_stage_id: warm_pool_stage_id,
        position: 0,
        type: "quality",
        required: true,
        params: %{"checks" => ["smoke", "health"]},
        inserted_at: now,
        updated_at: now
      },
      %{
        id: uuid(),
        pipeline_stage_id: test_stage_id,
        position: 0,
        type: "quality",
        required: true,
        params: %{"checks" => ["unit", "boundary"]},
        inserted_at: now,
        updated_at: now
      },
      %{
        id: uuid(),
        pipeline_stage_id: deploy_stage_id,
        position: 0,
        type: "manual_approval",
        required: true,
        params: %{"approvers" => ["release-managers"]},
        inserted_at: now,
        updated_at: now
      }
    ])
  end

  defp delete_default_pipeline do
    repo().query!("DELETE FROM pipeline_configs")
  end

  defp uuid do
    Ecto.UUID.generate() |> Ecto.UUID.dump!()
  end
end
