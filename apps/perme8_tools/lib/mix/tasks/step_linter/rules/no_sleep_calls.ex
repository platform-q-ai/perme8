defmodule Mix.Tasks.StepLinter.Rules.NoSleepCalls do
  @moduledoc """
  Detects sleep calls in step definitions.

  Sleep calls (`Process.sleep`, `:timer.sleep`) in step definitions cause:
  - **Slow tests**: Fixed delays add up across test suites
  - **Flaky tests**: Timing-based waits are unreliable
  - **Poor feedback**: Tests pass/fail based on machine speed

  ## How to Fix

  Use polling/retry helpers instead of fixed sleeps:

  ### Bad (sleep):
  ```elixir
  step "the update is processed", context do
    Process.sleep(1000)
    {:ok, context}
  end
  ```

  ### Good (wait_until):
  ```elixir
  step "the update is processed", context do
    wait_until(fn -> check_processed() end, timeout: 2000)
    {:ok, context}
  end
  ```

  ## Available Helpers

  Use `Jarga.Test.StepHelpers.wait_until/2` for polling:

  ```elixir
  wait_until(fn -> condition_met?() end, timeout: 2000, interval: 100)
  ```
  """

  @behaviour Mix.Tasks.StepLinter.Rule

  @impl true
  def name, do: "no_sleep_calls"

  @impl true
  def description do
    "Detects Process.sleep and :timer.sleep calls - use wait_until helpers instead"
  end

  @impl true
  def check(%{body_ast: nil}), do: []

  def check(%{body_ast: body_ast, pattern: pattern, line: step_line}) do
    sleep_calls = find_sleep_calls(body_ast, step_line)

    Enum.map(sleep_calls, fn sleep_call ->
      %{
        rule: name(),
        message:
          "Step \"#{truncate(pattern, 50)}\" contains #{sleep_call.function} call at line #{sleep_call.line}. " <>
            "Use wait_until helper instead for more reliable tests.",
        severity: :warning,
        line: sleep_call.line,
        details: %{
          function: sleep_call.function,
          pattern: pattern
        }
      }
    end)
  end

  defp find_sleep_calls(ast, base_line) do
    {_ast, calls} = Macro.prewalk(ast, [], &find_sleep_nodes(&1, &2, base_line))
    calls
  end

  # Process.sleep(ms)
  defp find_sleep_nodes(
         {{:., _, [{:__aliases__, _, [:Process]}, :sleep]}, meta, _args} = ast,
         acc,
         base_line
       ) do
    line = Keyword.get(meta, :line, base_line)
    {ast, [%{function: "Process.sleep", line: line} | acc]}
  end

  # :timer.sleep(ms)
  defp find_sleep_nodes(
         {{:., _, [:timer, :sleep]}, meta, _args} = ast,
         acc,
         base_line
       ) do
    line = Keyword.get(meta, :line, base_line)
    {ast, [%{function: ":timer.sleep", line: line} | acc]}
  end

  defp find_sleep_nodes(ast, acc, _base_line), do: {ast, acc}

  defp truncate(string, max_length) when byte_size(string) <= max_length, do: string

  defp truncate(string, max_length) do
    String.slice(string, 0, max_length - 3) <> "..."
  end
end
