defmodule ExoDashboard.TestRuns.Domain.Entities.TestCaseResultTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Domain.Entities.TestCaseResult
  alias ExoDashboard.TestRuns.Domain.Entities.TestStepResult

  describe "new/1" do
    test "creates a test case result with all fields" do
      result =
        TestCaseResult.new(
          pickle_id: "pickle-1",
          test_case_id: "tc-1",
          test_case_started_id: "tcs-1",
          feature_uri: "apps/jarga_web/test/features/login.browser.feature",
          scenario_name: "User logs in",
          attempt: 0
        )

      assert result.pickle_id == "pickle-1"
      assert result.test_case_id == "tc-1"
      assert result.test_case_started_id == "tcs-1"
      assert result.feature_uri == "apps/jarga_web/test/features/login.browser.feature"
      assert result.scenario_name == "User logs in"
      assert result.attempt == 0
    end

    test "defaults step_results to empty list" do
      result = TestCaseResult.new(pickle_id: "pickle-1")
      assert result.step_results == []
    end

    test "defaults status to :pending" do
      result = TestCaseResult.new(pickle_id: "pickle-1")
      assert result.status == :pending
    end
  end

  describe "add_step_result/2" do
    test "appends a step result" do
      result = TestCaseResult.new(pickle_id: "p-1")

      step = TestStepResult.new(test_step_id: "ts-1", status: :passed, duration_ms: 10)
      updated = TestCaseResult.add_step_result(result, step)

      assert length(updated.step_results) == 1
      assert hd(updated.step_results).test_step_id == "ts-1"
    end

    test "recomputes status to :passed when all steps pass" do
      result = TestCaseResult.new(pickle_id: "p-1")

      step1 = TestStepResult.new(test_step_id: "ts-1", status: :passed)
      step2 = TestStepResult.new(test_step_id: "ts-2", status: :passed)

      updated =
        result
        |> TestCaseResult.add_step_result(step1)
        |> TestCaseResult.add_step_result(step2)

      assert updated.status == :passed
    end

    test "recomputes status to :failed when any step fails" do
      result = TestCaseResult.new(pickle_id: "p-1")

      step1 = TestStepResult.new(test_step_id: "ts-1", status: :passed)
      step2 = TestStepResult.new(test_step_id: "ts-2", status: :failed, error_message: "boom")

      updated =
        result
        |> TestCaseResult.add_step_result(step1)
        |> TestCaseResult.add_step_result(step2)

      assert updated.status == :failed
    end

    test "recomputes status to :pending when some steps pending" do
      result = TestCaseResult.new(pickle_id: "p-1")

      step1 = TestStepResult.new(test_step_id: "ts-1", status: :passed)
      step2 = TestStepResult.new(test_step_id: "ts-2", status: :pending)

      updated =
        result
        |> TestCaseResult.add_step_result(step1)
        |> TestCaseResult.add_step_result(step2)

      assert updated.status == :pending
    end
  end
end
