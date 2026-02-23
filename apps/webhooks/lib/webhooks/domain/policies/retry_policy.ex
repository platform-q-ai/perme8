defmodule Webhooks.Domain.Policies.RetryPolicy do
  @moduledoc """
  Pure retry policy for webhook delivery attempts.

  Defines the maximum number of retries and the exponential
  backoff schedule for failed webhook deliveries.

  Backoff formula: `15 * 2^attempt` seconds
  Schedule: 15s, 30s, 60s, 120s, 240s
  """

  @max_retries 5
  @base_delay_seconds 15

  @doc "Returns the maximum number of retry attempts."
  @spec max_retries() :: non_neg_integer()
  def max_retries, do: @max_retries

  @doc """
  Returns true if a delivery should be retried based on the current attempt count.

  Retries are allowed for attempts 0 through 4 (5 total attempts).
  """
  @spec should_retry?(non_neg_integer()) :: boolean()
  def should_retry?(attempts) when is_integer(attempts) do
    attempts < @max_retries
  end

  @doc """
  Calculates the next retry delay in seconds using exponential backoff.

  Formula: `15 * 2^attempt`
  - Attempt 0: 15 seconds
  - Attempt 1: 30 seconds
  - Attempt 2: 60 seconds
  - Attempt 3: 120 seconds
  - Attempt 4: 240 seconds
  """
  @spec next_retry_delay_seconds(non_neg_integer()) :: non_neg_integer()
  def next_retry_delay_seconds(attempts) when is_integer(attempts) do
    @base_delay_seconds * Integer.pow(2, attempts)
  end
end
