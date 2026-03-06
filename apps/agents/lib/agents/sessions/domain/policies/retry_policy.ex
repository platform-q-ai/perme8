defmodule Agents.Sessions.Domain.Policies.RetryPolicy do
  @moduledoc """
  Pure retry and escalation rules for session task failures.

  ## Backoff Curve

  Uses base-5 exponential backoff capped at 10 minutes:

  | Retry | Delay             |
  |-------|-------------------|
  | 0     | 5 s  (5 * 5^0)    |
  | 1     | 25 s (5 * 5^1)    |
  | 2     | 125 s (~2 min)    |
  | 3+    | 600 s (10 min cap)|

  Configure `max_retries` via `:agents, :sessions, :max_retries` (default 3).
  """

  @retryable_errors MapSet.new([
                      "container_crashed",
                      "runner_start_failed",
                      "container_timeout",
                      "infra_error"
                    ])

  @permanent_errors MapSet.new([
                      "user_cancelled",
                      "validation_error",
                      "auth_error"
                    ])

  @base_delay_ms 5_000
  @max_delay_ms 600_000
  @default_max_retries 3

  @doc """
  Returns true when a failed task is eligible for retry.
  """
  @spec retryable?(map()) :: boolean()
  def retryable?(task_like) when is_map(task_like) do
    retry_count = value(task_like, :retry_count) || 0

    classify_failure(value(task_like, :error)) == :retryable and
      retry_count < max_retries()
  end

  @doc """
  Returns exponential backoff in milliseconds, capped at 10 minutes.
  """
  @spec next_retry_delay(non_neg_integer()) :: non_neg_integer()
  def next_retry_delay(retry_count) when is_integer(retry_count) and retry_count >= 0 do
    @base_delay_ms
    |> Kernel.*(Integer.pow(5, retry_count))
    |> min(@max_delay_ms)
  end

  @doc """
  Returns true when retry attempts should be escalated.
  """
  @spec should_escalate?(map()) :: boolean()
  def should_escalate?(task_like) when is_map(task_like) do
    (value(task_like, :retry_count) || 0) >= max_retries()
  end

  @doc """
  Classifies a failure error string as retryable or permanent.
  """
  @spec classify_failure(String.t() | nil) :: :retryable | :permanent
  def classify_failure(error) when is_binary(error) do
    cond do
      MapSet.member?(@retryable_errors, error) -> :retryable
      MapSet.member?(@permanent_errors, error) -> :permanent
      true -> :permanent
    end
  end

  def classify_failure(_), do: :permanent

  @doc """
  Returns maximum retry attempts from config or default.
  """
  @spec max_retries() :: pos_integer()
  def max_retries do
    :agents
    |> Application.get_env(:sessions, [])
    |> Keyword.get(:max_retries, @default_max_retries)
  end

  defp value(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} -> val
      :error -> Map.get(map, Atom.to_string(key))
    end
  end
end
