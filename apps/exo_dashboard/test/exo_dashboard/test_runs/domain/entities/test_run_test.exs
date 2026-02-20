defmodule ExoDashboard.TestRuns.Domain.Entities.TestRunTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Domain.Entities.TestRun

  describe "new/1" do
    test "creates a test run with all fields" do
      run =
        TestRun.new(
          id: "run-1",
          config_path: "apps/jarga_web/exo-bdd.config.ts",
          scope: {:app, "jarga_web"}
        )

      assert run.id == "run-1"
      assert run.config_path == "apps/jarga_web/exo-bdd.config.ts"
      assert run.scope == {:app, "jarga_web"}
    end

    test "defaults status to :pending" do
      run = TestRun.new(id: "run-2")
      assert run.status == :pending
    end

    test "defaults test_cases to empty list" do
      run = TestRun.new(id: "run-3")
      assert run.test_cases == []
    end

    test "defaults progress to zero counts" do
      run = TestRun.new(id: "run-4")

      assert run.progress == %{
               total: 0,
               passed: 0,
               failed: 0,
               skipped: 0,
               pending: 0
             }
    end

    test "started_at and finished_at default to nil" do
      run = TestRun.new(id: "run-5")
      assert run.started_at == nil
      assert run.finished_at == nil
    end
  end

  describe "start/1" do
    test "transitions status to :running and sets started_at" do
      run = TestRun.new(id: "run-1")
      started = TestRun.start(run)

      assert started.status == :running
      assert %DateTime{} = started.started_at
    end

    test "preserves other fields" do
      run = TestRun.new(id: "run-1", config_path: "some/path")
      started = TestRun.start(run)

      assert started.id == "run-1"
      assert started.config_path == "some/path"
    end
  end

  describe "finish/2" do
    test "transitions status to :passed and sets finished_at" do
      run = TestRun.new(id: "run-1") |> TestRun.start()
      finished = TestRun.finish(run, :passed)

      assert finished.status == :passed
      assert %DateTime{} = finished.finished_at
    end

    test "transitions status to :failed" do
      run = TestRun.new(id: "run-1") |> TestRun.start()
      finished = TestRun.finish(run, :failed)

      assert finished.status == :failed
    end

    test "preserves started_at" do
      run = TestRun.new(id: "run-1") |> TestRun.start()
      started_at = run.started_at
      finished = TestRun.finish(run, :passed)

      assert finished.started_at == started_at
    end
  end
end
