defmodule Agents.Pipeline.Infrastructure.StageExecutor do
  @moduledoc "Default shell-based stage executor. Uses docker exec when a container is present."

  @behaviour Agents.Pipeline.Application.Behaviours.StageExecutorBehaviour

  alias Agents.Pipeline.Domain.Entities.Stage

  @impl true
  def execute(%Stage{} = stage, context) do
    Enum.reduce_while(
      stage.steps,
      {:ok, %{output: "", exit_code: 0, metadata: %{steps: []}}},
      fn step, _acc ->
        case run_step(step, context) do
          {:ok, result} ->
            {:cont, {:ok, merge_success_result(result)}}

          {:error, result} ->
            {:halt, {:error, merge_failure_result(result)}}
        end
      end
    )
  end

  defp run_step(step, context) do
    command = step.run

    {program, args} =
      case Map.get(context, :container_id) || Map.get(context, "container_id") do
        nil -> {"bash", ["-lc", command]}
        container_id -> {"docker", ["exec", container_id, "bash", "-lc", command]}
      end

    opts = [stderr_to_stdout: true]

    try do
      {output, exit_code} = System.cmd(program, args, opts)

      result = %{output: output, exit_code: exit_code, metadata: %{"step" => step.name}}

      if exit_code == 0 do
        {:ok, result}
      else
        {:error, Map.put(result, :reason, :non_zero_exit)}
      end
    rescue
      error ->
        {:error,
         %{
           output: Exception.message(error),
           exit_code: nil,
           reason: error.__struct__,
           metadata: %{"step" => step.name}
         }}
    end
  end

  defp merge_success_result(result),
    do: %{output: result.output, exit_code: result.exit_code, metadata: result.metadata}

  defp merge_failure_result(result) do
    %{
      output: result.output,
      exit_code: result.exit_code,
      reason: result.reason,
      metadata: result.metadata
    }
  end
end
