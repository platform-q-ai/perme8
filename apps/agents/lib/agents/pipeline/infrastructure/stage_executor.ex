defmodule Agents.Pipeline.Infrastructure.StageExecutor do
  @moduledoc "Default shell-based stage executor. Uses docker exec when a container is present."

  @behaviour Agents.Pipeline.Application.Behaviours.StageExecutorBehaviour

  alias Agents.Pipeline.Domain.Entities.Stage

  @impl true
  def execute(%Stage{} = stage, context) do
    Enum.reduce_while(stage.steps, {:ok, initial_result()}, fn step, {:ok, acc} ->
      case run_step_with_retries(step, context) do
        {:ok, result} ->
          {:cont, {:ok, merge_success_result(acc, result)}}

        {:error, result} ->
          {:halt, {:error, merge_failure_result(acc, result)}}
      end
    end)
  end

  defp run_step_with_retries(step, context) do
    do_run_step_with_retries(step, context, 1)
  end

  defp do_run_step_with_retries(step, context, attempt) do
    case run_step(step, context, attempt) do
      {:ok, result} ->
        {:ok, result}

      {:error, _result} when attempt <= step.retries ->
        do_run_step_with_retries(step, context, attempt + 1)

      {:error, result} ->
        {:error, result}
    end
  end

  defp run_step(step, context, attempt) do
    command = compose_command(step, context)

    {program, args} =
      case Map.get(context, :container_id) || Map.get(context, "container_id") do
        nil -> {"bash", ["-lc", command]}
        container_id -> {"docker", ["exec", container_id, "bash", "-lc", command]}
      end

    opts = [stderr_to_stdout: true, env: Enum.into(step.env, [])]
    timeout_ms = timeout_ms(step.timeout_seconds)

    task =
      Task.async(fn ->
        try do
          {output, exit_code} = System.cmd(program, args, opts)
          {:ok, output, exit_code}
        rescue
          error -> {:raised, error}
        end
      end)

    task
    |> Task.yield(timeout_ms)
    |> Kernel.||(Task.shutdown(task, :brutal_kill))
    |> normalize_command_result(step, attempt, timeout_ms)
  end

  defp initial_result do
    %{output: "", exit_code: 0, metadata: %{"steps" => []}}
  end

  defp merge_success_result(acc, result) do
    %{
      output: append_output(acc.output, result.output),
      exit_code: result.exit_code,
      metadata: %{"steps" => acc.metadata["steps"] ++ [result.metadata]}
    }
  end

  defp merge_failure_result(acc, result) do
    %{
      output: append_output(acc.output, result.output),
      exit_code: result.exit_code,
      reason: result.reason,
      metadata: %{"steps" => acc.metadata["steps"] ++ [result.metadata]}
    }
  end

  defp append_output(nil, output), do: output || ""
  defp append_output(existing, nil), do: existing
  defp append_output("", output), do: output
  defp append_output(existing, output), do: existing <> "\n" <> output

  defp compose_command(step, context) do
    case branch_checkout_prefix(context) do
      nil -> step.run
      prefix -> prefix <> step.run
    end
  end

  defp branch_checkout_prefix(context) do
    branch =
      case Map.get(context, "trigger_type") do
        "on_merge" -> Map.get(context, "target_branch")
        _ -> Map.get(context, "source_branch") || Map.get(context, "target_branch")
      end

    if is_binary(branch) and branch != "" do
      "git checkout #{branch} >/dev/null 2>&1 && "
    else
      nil
    end
  end

  defp timeout_ms(nil), do: 30_000
  defp timeout_ms(seconds), do: seconds * 1000

  defp normalize_command_result({:ok, {:ok, output, exit_code}}, step, attempt, _timeout_ms) do
    result = %{
      output: output,
      exit_code: exit_code,
      metadata: %{
        "name" => step.name,
        "attempt" => attempt,
        "status" => if(exit_code == 0, do: "passed", else: "failed")
      }
    }

    if exit_code == 0 do
      {:ok, result}
    else
      {:error, Map.put(result, :reason, :non_zero_exit)}
    end
  end

  defp normalize_command_result({:ok, {:raised, error}}, step, attempt, _timeout_ms) do
    {:error,
     %{
       output: Exception.message(error),
       exit_code: nil,
       reason: error.__struct__,
       metadata: %{"name" => step.name, "attempt" => attempt, "status" => "failed"}
     }}
  end

  defp normalize_command_result(nil, step, attempt, timeout_ms) do
    {:error,
     %{
       output: "command timed out after #{timeout_ms}ms",
       exit_code: nil,
       reason: :timeout,
       metadata: %{"name" => step.name, "attempt" => attempt, "status" => "failed"}
     }}
  end
end
