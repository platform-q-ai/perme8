defmodule ExoDashboard.TestRuns.Domain.Entities.TestStepResultTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Domain.Entities.TestStepResult

  describe "new/1" do
    test "creates a test step result with all fields" do
      result =
        TestStepResult.new(
          test_step_id: "ts-1",
          status: :passed,
          duration_ms: 42,
          error_message: nil,
          exception: nil
        )

      assert result.test_step_id == "ts-1"
      assert result.status == :passed
      assert result.duration_ms == 42
      assert result.error_message == nil
      assert result.exception == nil
    end

    test "creates a failed step result with error details" do
      result =
        TestStepResult.new(
          test_step_id: "ts-2",
          status: :failed,
          duration_ms: 150,
          error_message: "Expected true, got false",
          exception: %{type: "AssertionError", message: "Expected true, got false"}
        )

      assert result.status == :failed
      assert result.error_message == "Expected true, got false"
      assert result.exception.type == "AssertionError"
    end

    test "supports all status values" do
      for status <- [:passed, :failed, :pending, :skipped, :undefined, :ambiguous] do
        result = TestStepResult.new(test_step_id: "ts", status: status)
        assert result.status == status
      end
    end

    test "defaults step_results fields to nil" do
      result = TestStepResult.new(test_step_id: "ts-3")
      assert result.status == nil
      assert result.duration_ms == nil
      assert result.error_message == nil
      assert result.exception == nil
    end
  end
end
