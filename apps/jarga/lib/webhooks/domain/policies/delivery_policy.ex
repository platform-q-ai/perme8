defmodule Jarga.Webhooks.Domain.Policies.DeliveryPolicy do
  @moduledoc """
  Pure policy for webhook delivery retry logic.

  Implements exponential backoff: delay = 60s * 2^(attempt - 1).
  No I/O, no side effects.
  """

  @base_delay_seconds 60

  @doc """
  Determines if a delivery should be retried.

  Returns `true` when attempts < max_attempts and status is "pending" or "failed".
  """
  @spec should_retry?(map(), pos_integer()) :: boolean()
  def should_retry?(%{status: "success"}, _max_attempts), do: false

  def should_retry?(%{attempts: attempts, status: status}, max_attempts)
      when status in ["pending", "failed"] and attempts < max_attempts,
      do: true

  def should_retry?(_delivery, _max_attempts), do: false

  @doc """
  Calculates the retry delay in seconds using exponential backoff.

  Formula: 60 * 2^(attempt - 1)

  ## Examples

      iex> next_retry_delay(1)
      60
      iex> next_retry_delay(3)
      240
  """
  @spec next_retry_delay(pos_integer()) :: pos_integer()
  def next_retry_delay(attempt) when is_integer(attempt) and attempt > 0 do
    @base_delay_seconds * Integer.pow(2, attempt - 1)
  end

  @doc """
  Calculates the next retry DateTime from a base time.
  """
  @spec next_retry_at(pos_integer(), DateTime.t()) :: DateTime.t()
  def next_retry_at(attempt, base_time) do
    delay = next_retry_delay(attempt)
    DateTime.add(base_time, delay, :second)
  end

  @doc """
  Checks if maximum retries have been exhausted.
  """
  @spec max_retries_exhausted?(non_neg_integer(), pos_integer()) :: boolean()
  def max_retries_exhausted?(attempts, max_attempts), do: attempts >= max_attempts
end
