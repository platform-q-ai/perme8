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
        case run_step_with_retries(step, context) do
          {:ok, result} ->
            {:cont, {:ok, merge_success_result(result)}}

          {:error, result} ->
            {:halt, {:error, merge_failure_result(result)}}
        end
      end
    )
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
      metadata: %{"step" => step.name, "attempt" => attempt}
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
       metadata: %{"step" => step.name, "attempt" => attempt}
     }}
  end

  defp normalize_command_result(nil, step, attempt, timeout_ms) do
    {:error,
     %{
       output: "command timed out after #{timeout_ms}ms",
       exit_code: nil,
       reason: :timeout,
       metadata: %{"step" => step.name, "attempt" => attempt}
     }}
  end
end
