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

    test "returns :skipped when all steps are skipped" do
      assert StatusPolicy.aggregate_status([:skipped, :skipped]) == :skipped
    end

    test "returns :skipped for single skipped step" do
      assert StatusPolicy.aggregate_status([:skipped]) == :skipped
    end

    test "returns :pending when passed and skipped both present" do
      # When there are both passed and skipped, the skipped branch requires
      # no passed steps, so it falls through to the catchall :pending
      assert StatusPolicy.aggregate_status([:passed, :skipped]) == :pending
    end

    test "returns :failed for single failed step" do
      assert StatusPolicy.aggregate_status([:failed]) == :failed
    end

    test "returns :pending for single pending step" do
      assert StatusPolicy.aggregate_status([:pending]) == :pending
    end

    test "handles :undefined status in the list" do
      assert StatusPolicy.aggregate_status([:undefined]) == :pending
    end

    test "returns :failed when :undefined and :failed both present" do
      assert StatusPolicy.aggregate_status([:undefined, :failed]) == :failed
    end

    test "returns :pending when :undefined and :passed both present" do
      assert StatusPolicy.aggregate_status([:undefined, :passed]) == :pending
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
