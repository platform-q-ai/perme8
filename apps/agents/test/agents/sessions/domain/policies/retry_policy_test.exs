defmodule Agents.Sessions.Domain.Policies.RetryPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.RetryPolicy

  describe "retryable?/1" do
    test "returns true for retryable errors when below max retries" do
      assert RetryPolicy.retryable?(%{error: "container_crashed", retry_count: 0})
      assert RetryPolicy.retryable?(%{error: "runner_start_failed", retry_count: 1})
      assert RetryPolicy.retryable?(%{error: "container_timeout", retry_count: 2})
      assert RetryPolicy.retryable?(%{error: "infra_error", retry_count: 0})
    end

    test "returns false for permanent errors" do
      refute RetryPolicy.retryable?(%{error: "user_cancelled", retry_count: 0})
      refute RetryPolicy.retryable?(%{error: "validation_error", retry_count: 0})
      refute RetryPolicy.retryable?(%{error: "auth_error", retry_count: 0})
    end

    test "returns false when retry_count has reached max retries" do
      refute RetryPolicy.retryable?(%{
               error: "container_crashed",
               retry_count: RetryPolicy.max_retries()
             })
    end
  end

  describe "next_retry_delay/1" do
    test "returns exponential backoff in milliseconds" do
      assert RetryPolicy.next_retry_delay(0) == 5_000
      assert RetryPolicy.next_retry_delay(1) == 25_000
      assert RetryPolicy.next_retry_delay(2) == 125_000
    end

    test "caps backoff at 600_000 ms" do
      assert RetryPolicy.next_retry_delay(5) == 600_000
      assert RetryPolicy.next_retry_delay(10) == 600_000
    end
  end

  describe "should_escalate?/1" do
    test "returns true when retry_count is at or above max retries" do
      assert RetryPolicy.should_escalate?(%{retry_count: RetryPolicy.max_retries()})
      assert RetryPolicy.should_escalate?(%{retry_count: RetryPolicy.max_retries() + 1})
      refute RetryPolicy.should_escalate?(%{retry_count: RetryPolicy.max_retries() - 1})
    end
  end

  describe "classify_failure/1" do
    test "classifies retryable and permanent failures" do
      assert RetryPolicy.classify_failure("container_crashed") == :retryable
      assert RetryPolicy.classify_failure("runner_start_failed") == :retryable
      assert RetryPolicy.classify_failure("container_timeout") == :retryable
      assert RetryPolicy.classify_failure("infra_error") == :retryable

      assert RetryPolicy.classify_failure("validation_error") == :permanent
      assert RetryPolicy.classify_failure("auth_error") == :permanent
      assert RetryPolicy.classify_failure("user_cancelled") == :permanent
      assert RetryPolicy.classify_failure("unknown") == :permanent
    end
  end

  describe "max_retries/0" do
    test "returns the default retry limit" do
      assert RetryPolicy.max_retries() == 3
    end
  end
end
