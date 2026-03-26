defmodule Agents.Pipeline.Application.PipelineConfigMapper do
  @moduledoc false

  alias Agents.Pipeline.Domain.Entities.{Gate, PipelineConfig, Stage, Step}

  @spec to_root_map(PipelineConfig.t()) :: map()
  def to_root_map(config) do
    %{
      "version" => config.version,
      "pipeline" => %{
        "name" => config.name,
        "description" => config.description,
        "merge_queue" => config.merge_queue,
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
      stages:
        Enum.with_index(config.stages)
        |> Enum.map(fn {stage, position} ->
          %{
            position: position,
            stage_id: stage.id,
            type: stage.type,
            schedule: stage.schedule,
            triggers: stage.triggers || [],
            depends_on: stage.depends_on || [],
            ticket_concurrency: stage.ticket_concurrency,
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
                  env: step.env || %{},
                  depends_on: step.depends_on || []
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
      stages:
        record.stages
        |> Enum.sort_by(& &1.position)
        |> Enum.map(&stage_from_record/1)
    })
  end

  defp stage_to_map(stage) do
    %{
      "id" => stage.id,
      "type" => stage.type,
      "schedule" => stage.schedule,
      "triggers" => stage.triggers || [],
      "depends_on" => stage.depends_on || [],
      "ticket_concurrency" => stage.ticket_concurrency,
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
      "env" => step.env || %{},
      "depends_on" => step.depends_on || []
    }
  end

  defp gate_to_map(gate) do
    Map.merge(%{"type" => gate.type, "required" => gate.required}, gate.params || %{})
  end

  defp stage_from_record(stage) do
    Stage.new(%{
      id: stage.stage_id,
      type: stage.type,
      schedule: stage.schedule,
      triggers: stage.triggers || [],
      depends_on: stage.depends_on || [],
      ticket_concurrency: stage.ticket_concurrency,
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
      env: step.env || %{},
      depends_on: step.depends_on || []
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
