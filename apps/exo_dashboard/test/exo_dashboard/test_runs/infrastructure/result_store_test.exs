defmodule ExoDashboard.TestRuns.Infrastructure.ResultStoreTest do
  use ExUnit.Case, async: false

  alias ExoDashboard.TestRuns.Infrastructure.ResultStore
  alias ExoDashboard.TestRuns.Domain.Entities.TestRun

  setup do
    # Start a fresh store for each test
    store = start_supervised!({ResultStore, name: :"test_store_#{:rand.uniform(1_000_000)}"})
    %{store: store}
  end

  describe "create_run/2 and get_run/2" do
    test "stores and retrieves a TestRun", %{store: store} do
      run = TestRun.new(id: "run-1", status: :pending)
      assert :ok = ResultStore.create_run(store, run)

      assert {:ok, stored_run} = ResultStore.get_run(store, "run-1")
      assert stored_run.id == "run-1"
      assert stored_run.status == :pending
    end

    test "returns {:error, :not_found} for missing run", %{store: store} do
      assert {:error, :not_found} = ResultStore.get_run(store, "nonexistent")
    end
  end

  describe "update_run/3" do
    test "applies a function to update the run", %{store: store} do
      run = TestRun.new(id: "run-2", status: :pending)
      ResultStore.create_run(store, run)

      ResultStore.update_run(store, "run-2", fn r -> %{r | status: :running} end)

      {:ok, updated} = ResultStore.get_run(store, "run-2")
      assert updated.status == :running
    end

    test "returns {:error, :not_found} for nonexistent run", %{store: store} do
      result = ResultStore.update_run(store, "nonexistent", fn r -> %{r | status: :running} end)
      assert {:error, :not_found} = result
    end
  end

  describe "register_pickle/4 and get_pickle/3" do
    test "stores and retrieves a pickle", %{store: store} do
      pickle = %{"id" => "pickle-1", "name" => "Test scenario", "uri" => "test.feature"}
      ResultStore.register_pickle(store, "run-1", "pickle-1", pickle)

      assert ResultStore.get_pickle(store, "run-1", "pickle-1") == pickle
    end

    test "returns nil for missing pickle", %{store: store} do
      assert ResultStore.get_pickle(store, "run-1", "nonexistent") == nil
    end
  end

  describe "register_test_case/4 and get_test_case_pickle_id/3" do
    test "stores test_case -> pickle_id mapping", %{store: store} do
      ResultStore.register_test_case(store, "run-1", "tc-1", "pickle-1")

      assert ResultStore.get_test_case_pickle_id(store, "run-1", "tc-1") == "pickle-1"
    end
  end

  describe "add_test_case_result/4 and get_test_case_result/3" do
    test "stores and retrieves a test case result", %{store: store} do
      result = %{
        pickle_id: "pickle-1",
        test_case_id: "tc-1",
        test_case_started_id: "tcs-1",
        status: :pending,
        step_results: []
      }

      ResultStore.add_test_case_result(store, "run-1", "tcs-1", result)

      assert stored = ResultStore.get_test_case_result(store, "run-1", "tcs-1")
      assert stored.status == :pending
    end
  end

  describe "list_runs/1" do
    test "returns all stored runs", %{store: store} do
      run1 = TestRun.new(id: "run-a", status: :pending)
      run2 = TestRun.new(id: "run-b", status: :running)

      ResultStore.create_run(store, run1)
      ResultStore.create_run(store, run2)

      runs = ResultStore.list_runs(store)
      ids = Enum.map(runs, & &1.id) |> Enum.sort()
      assert ids == ["run-a", "run-b"]
    end
  end

  describe "get_test_case_results/2" do
    test "returns all test case results for a run", %{store: store} do
      r1 = %{test_case_started_id: "tcs-1", status: :passed, step_results: []}
      r2 = %{test_case_started_id: "tcs-2", status: :failed, step_results: []}

      ResultStore.add_test_case_result(store, "run-1", "tcs-1", r1)
      ResultStore.add_test_case_result(store, "run-1", "tcs-2", r2)

      results = ResultStore.get_test_case_results(store, "run-1")
      assert length(results) == 2
    end
  end
end
