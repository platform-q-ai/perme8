defmodule ExoDashboard.Integration.PubsubStreamingTest do
  @moduledoc """
  Integration tests for the NDJSON -> ProcessEnvelope -> ResultStore pipeline.

  Verifies that:
  - NdjsonWatcher reads fixture NDJSON files and invokes callbacks
  - ProcessEnvelope processes a full stream and updates the ResultStore
  - ResultStore accumulates correct final state from a full stream
  """
  use ExUnit.Case, async: false

  alias ExoDashboard.TestRuns.Application.UseCases.ProcessEnvelope
  alias ExoDashboard.TestRuns.Domain.Entities.TestRun
  alias ExoDashboard.TestRuns.Infrastructure.{NdjsonWatcher, ResultStore}

  @fixtures_dir Path.expand("../../support/fixtures", __DIR__)

  setup do
    # Start a fresh ResultStore for each test
    store_name = :"result_store_#{:erlang.unique_integer([:positive])}"
    {:ok, store} = ResultStore.start_link(name: store_name)

    %{store: store}
  end

  describe "NdjsonWatcher reads fixture files" do
    test "reads simple_run.ndjson and delivers all envelopes", %{store: _store} do
      path = Path.join(@fixtures_dir, "simple_run.ndjson")
      test_pid = self()

      {:ok, watcher} =
        NdjsonWatcher.start_link(
          path: path,
          callback: fn envelope -> send(test_pid, {:envelope, envelope}) end,
          poll_interval: 10
        )

      ref = Process.monitor(watcher)

      # Wait for watcher to finish (it auto-stops on testRunFinished)
      assert_receive {:DOWN, ^ref, :process, ^watcher, :normal}, 5_000

      # Collect all envelopes we received
      envelopes = collect_envelopes()

      # Should have all envelope types from the fixture
      envelope_types = Enum.flat_map(envelopes, &Map.keys/1) |> MapSet.new()

      assert "meta" in envelope_types
      assert "testRunStarted" in envelope_types
      assert "pickle" in envelope_types
      assert "testCase" in envelope_types
      assert "testCaseStarted" in envelope_types
      assert "testStepFinished" in envelope_types
      assert "testCaseFinished" in envelope_types
      assert "testRunFinished" in envelope_types
    end

    test "reads failed_run.ndjson and delivers all envelopes" do
      path = Path.join(@fixtures_dir, "failed_run.ndjson")
      test_pid = self()

      {:ok, watcher} =
        NdjsonWatcher.start_link(
          path: path,
          callback: fn envelope -> send(test_pid, {:envelope, envelope}) end,
          poll_interval: 10
        )

      ref = Process.monitor(watcher)
      assert_receive {:DOWN, ^ref, :process, ^watcher, :normal}, 5_000

      envelopes = collect_envelopes()

      # Verify the failed step has an error message
      step_finished =
        Enum.filter(envelopes, &Map.has_key?(&1, "testStepFinished"))

      failed_steps =
        Enum.filter(step_finished, fn envelope ->
          envelope["testStepFinished"]["testStepResult"]["status"] == "FAILED"
        end)

      assert length(failed_steps) == 1

      failed_step = hd(failed_steps)
      assert failed_step["testStepFinished"]["testStepResult"]["message"] != nil
    end
  end

  describe "ProcessEnvelope processes full NDJSON stream" do
    test "processes simple_run.ndjson and accumulates correct state", %{store: store} do
      run_id = "integration-test-run-1"
      run = TestRun.new(id: run_id, scope: :app)
      ResultStore.create_run(store, run)

      # Read and process all envelopes from fixture
      path = Path.join(@fixtures_dir, "simple_run.ndjson")
      envelopes = read_ndjson_file(path)

      for envelope <- envelopes do
        ProcessEnvelope.execute(run_id, envelope, store: store, store_mod: ResultStore)
      end

      # Verify final run state
      {:ok, final_run} = ResultStore.get_run(store, run_id)
      assert final_run.status == :passed

      # Verify test case results
      results = ResultStore.get_test_case_results(store, run_id)
      assert length(results) == 1

      result = hd(results)
      assert result[:status] == :passed
      assert length(result[:step_results]) == 3

      # All steps should be passed
      for step <- result[:step_results] do
        assert step.status == :passed
        assert step.duration_ms >= 0
      end
    end

    test "processes failed_run.ndjson and marks run as failed", %{store: store} do
      run_id = "integration-test-run-2"
      run = TestRun.new(id: run_id, scope: :app)
      ResultStore.create_run(store, run)

      path = Path.join(@fixtures_dir, "failed_run.ndjson")
      envelopes = read_ndjson_file(path)

      for envelope <- envelopes do
        ProcessEnvelope.execute(run_id, envelope, store: store, store_mod: ResultStore)
      end

      # Verify final run state
      {:ok, final_run} = ResultStore.get_run(store, run_id)
      assert final_run.status == :failed

      # Verify test case results
      results = ResultStore.get_test_case_results(store, run_id)
      assert length(results) == 1

      result = hd(results)
      assert result[:status] == :failed
      assert length(result[:step_results]) == 3

      # Check individual step statuses
      statuses = Enum.map(result[:step_results], & &1.status)
      assert statuses == [:passed, :failed, :skipped]

      # The failed step should have an error message
      failed_step = Enum.find(result[:step_results], &(&1.status == :failed))
      assert failed_step.error_message == "Expected login to fail but succeeded"
    end
  end

  describe "ResultStore accumulates correct final state" do
    test "preserves pickle and test case mappings", %{store: store} do
      run_id = "integration-test-run-3"
      run = TestRun.new(id: run_id, scope: :app)
      ResultStore.create_run(store, run)

      path = Path.join(@fixtures_dir, "simple_run.ndjson")
      envelopes = read_ndjson_file(path)

      for envelope <- envelopes do
        ProcessEnvelope.execute(run_id, envelope, store: store, store_mod: ResultStore)
      end

      # Verify pickle was registered
      pickle = ResultStore.get_pickle(store, run_id, "pickle-1")
      assert pickle != nil
      assert pickle["name"] == "Successful login"
      assert pickle["uri"] == "features/login.feature"

      # Verify test case -> pickle mapping
      pickle_id = ResultStore.get_test_case_pickle_id(store, run_id, "test-case-1")
      assert pickle_id == "pickle-1"

      # Verify test case result has feature URI and scenario name
      result = ResultStore.get_test_case_result(store, run_id, "tcs-1")
      assert result[:feature_uri] == "features/login.feature"
      assert result[:scenario_name] == "Successful login"
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp read_ndjson_file(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  defp collect_envelopes do
    collect_envelopes([])
  end

  defp collect_envelopes(acc) do
    receive do
      {:envelope, envelope} -> collect_envelopes([envelope | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end
end
