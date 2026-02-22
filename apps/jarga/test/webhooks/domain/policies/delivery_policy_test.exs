defmodule Jarga.Webhooks.Domain.Policies.DeliveryPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Policies.DeliveryPolicy

  describe "should_retry?/2" do
    test "returns true when attempts < max_attempts and status is pending" do
      delivery = %{attempts: 1, status: "pending"}
      assert DeliveryPolicy.should_retry?(delivery, 5) == true
    end

    test "returns true when attempts < max_attempts and status is failed" do
      delivery = %{attempts: 3, status: "failed"}
      assert DeliveryPolicy.should_retry?(delivery, 5) == true
    end

    test "returns false when attempts >= max_attempts" do
      delivery = %{attempts: 5, status: "pending"}
      assert DeliveryPolicy.should_retry?(delivery, 5) == false
    end

    test "returns false when status is success" do
      delivery = %{attempts: 1, status: "success"}
      assert DeliveryPolicy.should_retry?(delivery, 5) == false
    end

    test "returns false when attempts exceed max_attempts" do
      delivery = %{attempts: 6, status: "pending"}
      assert DeliveryPolicy.should_retry?(delivery, 5) == false
    end
  end

  describe "next_retry_delay/1" do
    test "returns 60 seconds for attempt 1 (exponential backoff)" do
      assert DeliveryPolicy.next_retry_delay(1) == 60
    end

    test "returns 120 seconds for attempt 2" do
      assert DeliveryPolicy.next_retry_delay(2) == 120
    end

    test "returns 240 seconds for attempt 3" do
      assert DeliveryPolicy.next_retry_delay(3) == 240
    end

    test "returns 480 seconds for attempt 4" do
      assert DeliveryPolicy.next_retry_delay(4) == 480
    end

    test "returns 960 seconds for attempt 5" do
      assert DeliveryPolicy.next_retry_delay(5) == 960
    end
  end

  describe "next_retry_at/2" do
    test "returns DateTime offset from base by next_retry_delay" do
      base_time = ~U[2026-01-01 12:00:00Z]
      result = DeliveryPolicy.next_retry_at(1, base_time)

      expected = DateTime.add(base_time, 60, :second)
      assert result == expected
    end

    test "calculates correct offset for attempt 3" do
      base_time = ~U[2026-01-01 12:00:00Z]
      result = DeliveryPolicy.next_retry_at(3, base_time)

      expected = DateTime.add(base_time, 240, :second)
      assert result == expected
    end
  end

  describe "max_retries_exhausted?/2" do
    test "returns true when attempts >= max_attempts" do
      assert DeliveryPolicy.max_retries_exhausted?(5, 5) == true
    end

    test "returns true when attempts exceed max_attempts" do
      assert DeliveryPolicy.max_retries_exhausted?(6, 5) == true
    end

    test "returns false when attempts < max_attempts" do
      assert DeliveryPolicy.max_retries_exhausted?(3, 5) == false
    end
  end
end
