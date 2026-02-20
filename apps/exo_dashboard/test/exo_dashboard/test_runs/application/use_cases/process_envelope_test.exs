defmodule ExoDashboard.TestRuns.Application.UseCases.ProcessEnvelopeTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Application.UseCases.ProcessEnvelope

  # Simple Agent-based mock store for testing
  defmodule MockStore do
    def start_link do
      Agent.start_link(fn ->
        %{calls: [], pickles: %{}, test_cases: %{}, results: %{}, run: nil}
      end)
    end

    def update_run(agent, run_id, fun) do
      Agent.update(agent, fn state ->
        %{state | calls: state.calls ++ [{:update_run, run_id, fun}]}
      end)

      :ok
    end

    def register_pickle(agent, run_id, pickle_id, pickle) do
      Agent.update(agent, fn state ->
        %{
          state
          | calls: state.calls ++ [{:register_pickle, run_id, pickle_id}],
            pickles: Map.put(state.pickles, pickle_id, pickle)
        }
      end)

      :ok
    end

    def register_test_case(agent, run_id, test_case_id, pickle_id) do
      Agent.update(agent, fn state ->
        %{
          state
          | calls: state.calls ++ [{:register_test_case, run_id, test_case_id, pickle_id}],
            test_cases: Map.put(state.test_cases, test_case_id, pickle_id)
        }
      end)

      :ok
    end

    def add_test_case_result(agent, run_id, test_case_started_id, result) do
      Agent.update(agent, fn state ->
        %{
          state
          | calls: state.calls ++ [{:add_test_case_result, run_id, test_case_started_id, result}],
            results: Map.put(state.results, test_case_started_id, result)
        }
      end)

      :ok
    end

    def get_pickle(agent, _run_id, pickle_id) do
      Agent.get(agent, fn state -> Map.get(state.pickles, pickle_id) end)
    end

    def get_test_case_pickle_id(agent, _run_id, test_case_id) do
      Agent.get(agent, fn state -> Map.get(state.test_cases, test_case_id) end)
    end

    def get_test_case_result(agent, _run_id, test_case_started_id) do
      Agent.get(agent, fn state -> Map.get(state.results, test_case_started_id) end)
    end

    def get_calls(agent) do
      Agent.get(agent, fn state -> state.calls end)
    end
  end

  setup do
    {:ok, store} = MockStore.start_link()
    %{store: store}
  end

  describe "execute/3 with testRunStarted" do
    test "updates run status to :running", %{store: store} do
      envelope = %{
        "testRunStarted" => %{
          "timestamp" => %{"seconds" => 1_000_000, "nanos" => 0}
        }
      }

      assert :ok == ProcessEnvelope.execute("run-1", envelope, store: store, store_mod: MockStore)

      calls = MockStore.get_calls(store)
      assert [{:update_run, "run-1", _fun}] = calls
    end
  end

  describe "execute/3 with pickle" do
    test "registers pickle in store", %{store: store} do
      envelope = %{
        "pickle" => %{
          "id" => "pickle-1",
          "uri" => "login.feature",
          "name" => "User logs in",
          "steps" => [%{"id" => "ps-1", "text" => "given I am on login"}],
          "astNodeIds" => ["scenario-1"]
        }
      }

      assert :ok == ProcessEnvelope.execute("run-1", envelope, store: store, store_mod: MockStore)

      calls = MockStore.get_calls(store)
      assert [{:register_pickle, "run-1", "pickle-1"}] = calls
    end
  end

  describe "execute/3 with testCase" do
    test "registers test case mapping", %{store: store} do
      envelope = %{
        "testCase" => %{
          "id" => "tc-1",
          "pickleId" => "pickle-1",
          "testSteps" => []
        }
      }

      assert :ok == ProcessEnvelope.execute("run-1", envelope, store: store, store_mod: MockStore)

      calls = MockStore.get_calls(store)
      assert [{:register_test_case, "run-1", "tc-1", "pickle-1"}] = calls
    end
  end

  describe "execute/3 with testCaseStarted" do
    test "creates a new TestCaseResult in store", %{store: store} do
      # Pre-register test case -> pickle mapping
      MockStore.register_test_case(store, "run-1", "tc-1", "pickle-1")

      MockStore.register_pickle(store, "run-1", "pickle-1", %{
        "id" => "pickle-1",
        "uri" => "login.feature",
        "name" => "User logs in"
      })

      envelope = %{
        "testCaseStarted" => %{
          "id" => "tcs-1",
          "testCaseId" => "tc-1",
          "attempt" => 0,
          "timestamp" => %{"seconds" => 1_000_000, "nanos" => 0}
        }
      }

      assert :ok == ProcessEnvelope.execute("run-1", envelope, store: store, store_mod: MockStore)

      calls = MockStore.get_calls(store)
      # Last call should be add_test_case_result
      result_calls =
        Enum.filter(calls, fn
          {:add_test_case_result, _, _, _} -> true
          _ -> false
        end)

      assert length(result_calls) >= 1
    end
  end

  describe "execute/3 with testStepFinished" do
    test "adds step result to the correct test case", %{store: store} do
      # Setup: register pickle, test case, and initial result
      MockStore.register_test_case(store, "run-1", "tc-1", "pickle-1")

      MockStore.register_pickle(store, "run-1", "pickle-1", %{
        "id" => "pickle-1",
        "uri" => "login.feature",
        "name" => "User logs in"
      })

      MockStore.add_test_case_result(store, "run-1", "tcs-1", %{
        pickle_id: "pickle-1",
        test_case_id: "tc-1",
        test_case_started_id: "tcs-1",
        step_results: [],
        status: :pending
      })

      envelope = %{
        "testStepFinished" => %{
          "testCaseStartedId" => "tcs-1",
          "testStepId" => "ts-1",
          "testStepResult" => %{
            "status" => "PASSED",
            "duration" => %{"seconds" => 0, "nanos" => 42_000_000}
          },
          "timestamp" => %{"seconds" => 1_000_000, "nanos" => 0}
        }
      }

      assert :ok == ProcessEnvelope.execute("run-1", envelope, store: store, store_mod: MockStore)
    end
  end

  describe "execute/3 with testCaseFinished" do
    test "finalizes the test case result", %{store: store} do
      MockStore.add_test_case_result(store, "run-1", "tcs-1", %{
        pickle_id: "pickle-1",
        status: :passed,
        step_results: []
      })

      envelope = %{
        "testCaseFinished" => %{
          "testCaseStartedId" => "tcs-1",
          "timestamp" => %{"seconds" => 1_000_001, "nanos" => 0}
        }
      }

      assert :ok == ProcessEnvelope.execute("run-1", envelope, store: store, store_mod: MockStore)
    end
  end

  describe "execute/3 with testRunFinished" do
    test "updates run status to :passed or :failed", %{store: store} do
      envelope = %{
        "testRunFinished" => %{
          "success" => true,
          "timestamp" => %{"seconds" => 1_000_010, "nanos" => 0}
        }
      }

      assert :ok == ProcessEnvelope.execute("run-1", envelope, store: store, store_mod: MockStore)

      calls = MockStore.get_calls(store)
      assert [{:update_run, "run-1", _fun}] = calls
    end
  end
end
