defmodule ExoDashboard.TestRuns.Application.UseCases.StartTestRunTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Application.UseCases.StartTestRun

  # Mock store that tracks calls
  defmodule MockStore do
    def start_link do
      Agent.start_link(fn -> %{runs: %{}, calls: []} end)
    end

    def create_run(agent, run) do
      Agent.update(agent, fn state ->
        %{
          state
          | runs: Map.put(state.runs, run.id, run),
            calls: state.calls ++ [{:create_run, run.id}]
        }
      end)

      :ok
    end

    def get_calls(agent) do
      Agent.get(agent, fn state -> state.calls end)
    end

    def get_run(agent, run_id) do
      Agent.get(agent, fn state -> Map.get(state.runs, run_id) end)
    end
  end

  # Mock executor that records spawned commands
  defmodule MockExecutor do
    def start_link do
      Agent.start_link(fn -> [] end)
    end

    def start(agent, run_id, opts) do
      Agent.update(agent, fn calls -> calls ++ [{:start, run_id, opts}] end)
      {:ok, self()}
    end

    def get_calls(agent) do
      Agent.get(agent, fn calls -> calls end)
    end
  end

  # Mock PubSub that records broadcasts
  defmodule MockPubSub do
    def start_link do
      Agent.start_link(fn -> [] end)
    end

    def broadcast(agent, topic, message) do
      Agent.update(agent, fn calls -> calls ++ [{:broadcast, topic, message}] end)
      :ok
    end

    def get_calls(agent) do
      Agent.get(agent, fn calls -> calls end)
    end
  end

  setup do
    {:ok, store} = MockStore.start_link()
    {:ok, executor} = MockExecutor.start_link()
    {:ok, pubsub} = MockPubSub.start_link()
    %{store: store, executor: executor, pubsub: pubsub}
  end

  describe "execute/1 with :app scope" do
    test "creates a TestRun, stores it, and returns {:ok, run_id}", ctx do
      result =
        StartTestRun.execute(
          scope: {:app, "jarga_web"},
          store: ctx.store,
          store_mod: MockStore,
          executor: ctx.executor,
          executor_mod: MockExecutor,
          pubsub: ctx.pubsub,
          pubsub_mod: MockPubSub
        )

      assert {:ok, run_id} = result
      assert is_binary(run_id)

      store_calls = MockStore.get_calls(ctx.store)
      assert [{:create_run, ^run_id}] = store_calls
    end

    test "spawns executor with run config", ctx do
      {:ok, run_id} =
        StartTestRun.execute(
          scope: {:app, "jarga_web"},
          store: ctx.store,
          store_mod: MockStore,
          executor: ctx.executor,
          executor_mod: MockExecutor,
          pubsub: ctx.pubsub,
          pubsub_mod: MockPubSub
        )

      executor_calls = MockExecutor.get_calls(ctx.executor)
      assert [{:start, ^run_id, _opts}] = executor_calls
    end

    test "broadcasts :test_run_started via PubSub", ctx do
      {:ok, run_id} =
        StartTestRun.execute(
          scope: {:app, "jarga_web"},
          store: ctx.store,
          store_mod: MockStore,
          executor: ctx.executor,
          executor_mod: MockExecutor,
          pubsub: ctx.pubsub,
          pubsub_mod: MockPubSub
        )

      pubsub_calls = MockPubSub.get_calls(ctx.pubsub)

      assert [{:broadcast, "exo_dashboard:runs", {:test_run_started, ^run_id}}] =
               pubsub_calls
    end
  end

  describe "execute/1 with :feature scope" do
    test "creates TestRun with feature scope", ctx do
      {:ok, run_id} =
        StartTestRun.execute(
          scope: {:feature, "apps/jarga_web/test/features/login.browser.feature"},
          store: ctx.store,
          store_mod: MockStore,
          executor: ctx.executor,
          executor_mod: MockExecutor,
          pubsub: ctx.pubsub,
          pubsub_mod: MockPubSub
        )

      run = MockStore.get_run(ctx.store, run_id)
      assert run.scope == {:feature, "apps/jarga_web/test/features/login.browser.feature"}
    end
  end

  describe "execute/1 with :scenario scope" do
    test "creates TestRun with scenario scope", ctx do
      {:ok, run_id} =
        StartTestRun.execute(
          scope: {:scenario, "apps/jarga_web/test/features/login.browser.feature", 10},
          store: ctx.store,
          store_mod: MockStore,
          executor: ctx.executor,
          executor_mod: MockExecutor,
          pubsub: ctx.pubsub,
          pubsub_mod: MockPubSub
        )

      run = MockStore.get_run(ctx.store, run_id)

      assert run.scope ==
               {:scenario, "apps/jarga_web/test/features/login.browser.feature", 10}
    end
  end
end
