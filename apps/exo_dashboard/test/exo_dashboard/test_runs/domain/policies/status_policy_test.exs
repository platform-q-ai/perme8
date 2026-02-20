defmodule ExoDashboard.TestRuns.Domain.Policies.StatusPolicyTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Domain.Policies.StatusPolicy

  describe "aggregate_status/1" do
    test "returns :passed when all steps passed" do
      assert StatusPolicy.aggregate_status([:passed, :passed, :passed]) == :passed
    end

    test "returns :failed when any step failed" do
      assert StatusPolicy.aggregate_status([:passed, :failed, :passed]) == :failed
    end

    test "returns :pending when some steps pending and none failed" do
      assert StatusPolicy.aggregate_status([:passed, :pending]) == :pending
    end

    test "returns :running when no results yet (empty list)" do
      assert StatusPolicy.aggregate_status([]) == :running
    end

    test "returns :failed when failed and pending both present" do
      assert StatusPolicy.aggregate_status([:failed, :pending, :passed]) == :failed
    end

    test "returns :passed for single passed step" do
      assert StatusPolicy.aggregate_status([:passed]) == :passed
    end
  end

  describe "severity_rank/1" do
    test ":failed has highest rank" do
      assert StatusPolicy.severity_rank(:failed) == 4
    end

    test ":pending has second highest rank" do
      assert StatusPolicy.severity_rank(:pending) == 3
    end

    test ":skipped has third highest rank" do
      assert StatusPolicy.severity_rank(:skipped) == 2
    end

    test ":passed has lowest rank" do
      assert StatusPolicy.severity_rank(:passed) == 1
    end

    test "unknown status has rank 0" do
      assert StatusPolicy.severity_rank(:unknown) == 0
    end

    test "severity ordering is correct for sorting" do
      statuses = [:passed, :failed, :pending, :skipped]
      sorted = Enum.sort_by(statuses, &StatusPolicy.severity_rank/1, :desc)
      assert sorted == [:failed, :pending, :skipped, :passed]
    end
  end
end
