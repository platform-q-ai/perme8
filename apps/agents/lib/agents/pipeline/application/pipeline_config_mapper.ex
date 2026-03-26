defmodule Agents.Pipeline.Application.PipelineConfigMapper do
  @moduledoc false

  alias Agents.Pipeline.Domain.Entities.{DeployTarget, Gate, PipelineConfig, Stage, Step}

  @spec to_root_map(PipelineConfig.t()) :: map()
  def to_root_map(config) do
    %{
      "version" => config.version,
      "pipeline" => %{
        "name" => config.name,
        "description" => config.description,
        "merge_queue" => config.merge_queue,
        "deploy_targets" => Enum.map(config.deploy_targets, &deploy_target_to_map/1),
        "stages" => Enum.map(config.stages, &stage_to_map/1)
      }
    }
  end

  @spec to_editable_map(PipelineConfig.t()) :: map()
  def to_editable_map(config) do
    pipeline = to_root_map(config)["pipeline"]

    %{
      "version" => config.version,
      "name" => pipeline["name"],
      "description" => pipeline["description"],
      "merge_queue" => pipeline["merge_queue"],
      "deploy_targets" => pipeline["deploy_targets"],
      "stages" => pipeline["stages"]
    }
  end

  @spec to_persistence_attrs(PipelineConfig.t()) :: map()
  def to_persistence_attrs(config) do
    %{
      slug: "current",
      version: config.version,
      name: config.name,
      description: config.description,
      merge_queue: config.merge_queue || %{},
      deploy_targets:
        Enum.with_index(config.deploy_targets)
        |> Enum.map(fn {target, position} ->
          %{
            position: position,
            target_id: target.id,
            environment: target.environment,
            provider: target.provider,
            strategy: target.strategy,
            region: target.region,
            config: target.config || %{}
          }
        end),
      stages:
        Enum.with_index(config.stages)
        |> Enum.map(fn {stage, position} ->
          %{
            position: position,
            stage_id: stage.id,
            type: stage.type,
            deploy_target: stage.deploy_target,
            schedule: stage.schedule,
            config: stage.config || %{},
            steps:
              Enum.with_index(stage.steps)
              |> Enum.map(fn {step, step_position} ->
                %{
                  position: step_position,
                  name: step.name,
                  run: step.run,
                  timeout_seconds: step.timeout_seconds,
                  retries: step.retries,
                  conditions: step.conditions,
                  env: step.env || %{}
                }
              end),
            gates:
              Enum.with_index(stage.gates)
              |> Enum.map(fn {gate, gate_position} ->
                %{
                  position: gate_position,
                  type: gate.type,
                  required: gate.required,
                  params: gate.params || %{}
                }
              end)
          }
        end)
    }
  end

  @spec from_persistence_record(map()) :: PipelineConfig.t()
  def from_persistence_record(record) do
    PipelineConfig.new(%{
      version: record.version,
      name: record.name,
      description: record.description,
      merge_queue: record.merge_queue || %{},
      deploy_targets:
        record.deploy_targets
        |> Enum.sort_by(& &1.position)
        |> Enum.map(&deploy_target_from_record/1),
      stages:
        record.stages
        |> Enum.sort_by(& &1.position)
        |> Enum.map(&stage_from_record/1)
    })
  end

  defp deploy_target_to_map(target) do
    %{
      "id" => target.id,
      "environment" => target.environment,
      "provider" => target.provider,
      "strategy" => target.strategy,
      "region" => target.region
    }
    |> Map.merge(target.config || %{})
  end

  defp stage_to_map(stage) do
    %{
      "id" => stage.id,
      "type" => stage.type,
      "deploy_target" => stage.deploy_target,
      "schedule" => stage.schedule,
      "steps" => Enum.map(stage.steps, &step_to_map/1),
      "gates" => Enum.map(stage.gates, &gate_to_map/1)
    }
    |> Map.merge(stage.config || %{})
  end

  defp step_to_map(step) do
    %{
      "name" => step.name,
      "run" => step.run,
      "timeout_seconds" => step.timeout_seconds,
      "retries" => step.retries,
      "conditions" => step.conditions,
      "env" => step.env || %{}
    }
  end

  defp gate_to_map(gate) do
    Map.merge(%{"type" => gate.type, "required" => gate.required}, gate.params || %{})
  end

  defp deploy_target_from_record(target) do
    DeployTarget.new(%{
      id: target.target_id,
      environment: target.environment,
      provider: target.provider,
      strategy: target.strategy,
      region: target.region,
      config: target.config || %{}
    })
  end

  defp stage_from_record(stage) do
    Stage.new(%{
      id: stage.stage_id,
      type: stage.type,
      deploy_target: stage.deploy_target,
      schedule: stage.schedule,
      config: stage.config || %{},
      steps:
        stage.steps
        |> Enum.sort_by(& &1.position)
        |> Enum.map(&step_from_record/1),
      gates:
        stage.gates
        |> Enum.sort_by(& &1.position)
        |> Enum.map(&gate_from_record/1)
    })
  end

  defp step_from_record(step) do
    Step.new(%{
      name: step.name,
      run: step.run,
      timeout_seconds: step.timeout_seconds,
      retries: step.retries,
      conditions: step.conditions,
      env: step.env || %{}
    })
  end

  defp gate_from_record(gate) do
    Gate.new(%{
      type: gate.type,
      required: gate.required,
      params: gate.params || %{}
    })
  end
end
