defmodule Webhooks.Domain.Policies.RetryPolicyTest do
  use ExUnit.Case, async: true

  alias Webhooks.Domain.Policies.RetryPolicy

  describe "should_retry?/1" do
    test "returns true for 0 attempts" do
      assert RetryPolicy.should_retry?(0) == true
    end

    test "returns true for 1 attempt" do
      assert RetryPolicy.should_retry?(1) == true
    end

    test "returns true for 4 attempts" do
      assert RetryPolicy.should_retry?(4) == true
    end

    test "returns false for 5 attempts (max retries reached)" do
      assert RetryPolicy.should_retry?(5) == false
    end

    test "returns false for more than 5 attempts" do
      assert RetryPolicy.should_retry?(6) == false
      assert RetryPolicy.should_retry?(100) == false
    end
  end

  describe "next_retry_delay_seconds/1" do
    test "returns 15 seconds for attempt 0" do
      assert RetryPolicy.next_retry_delay_seconds(0) == 15
    end

    test "returns 30 seconds for attempt 1" do
      assert RetryPolicy.next_retry_delay_seconds(1) == 30
    end

    test "returns 60 seconds for attempt 2" do
      assert RetryPolicy.next_retry_delay_seconds(2) == 60
    end

    test "returns 120 seconds for attempt 3" do
      assert RetryPolicy.next_retry_delay_seconds(3) == 120
    end

    test "returns 240 seconds for attempt 4" do
      assert RetryPolicy.next_retry_delay_seconds(4) == 240
    end

    test "follows exponential backoff pattern (15 * 2^attempt)" do
      for attempt <- 0..4 do
        expected = 15 * Integer.pow(2, attempt)
        assert RetryPolicy.next_retry_delay_seconds(attempt) == expected
      end
    end
  end

  describe "max_retries/0" do
    test "returns 5" do
      assert RetryPolicy.max_retries() == 5
    end
  end
end
