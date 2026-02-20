defmodule ExoDashboard.TestRuns.Infrastructure.ResultStore do
  @moduledoc """
  ETS-backed GenServer for storing test run state and results.

  Provides fast lookups for runs, pickles, test cases, and results
  without requiring a database.
  """
  use GenServer

  @behaviour ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Stores a new TestRun."
  def create_run(server \\ __MODULE__, run) do
    GenServer.call(server, {:create_run, run})
  end

  @doc "Retrieves a TestRun by ID."
  def get_run(server \\ __MODULE__, run_id) do
    GenServer.call(server, {:get_run, run_id})
  end

  @doc "Updates a TestRun by applying a function."
  @impl ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour
  def update_run(run_id, fun), do: update_run(__MODULE__, run_id, fun)

  def update_run(server, run_id, fun) do
    GenServer.call(server, {:update_run, run_id, fun})
  end

  @doc "Registers a pickle for a run."
  @impl ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour
  def register_pickle(run_id, pickle_id, pickle),
    do: register_pickle(__MODULE__, run_id, pickle_id, pickle)

  def register_pickle(server, run_id, pickle_id, pickle) do
    GenServer.call(server, {:register_pickle, run_id, pickle_id, pickle})
  end

  @doc "Retrieves a pickle for a run."
  @impl ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour
  def get_pickle(run_id, pickle_id), do: get_pickle(__MODULE__, run_id, pickle_id)

  def get_pickle(server, run_id, pickle_id) do
    GenServer.call(server, {:get_pickle, run_id, pickle_id})
  end

  @doc "Registers a test case -> pickle ID mapping."
  @impl ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour
  def register_test_case(run_id, test_case_id, pickle_id),
    do: register_test_case(__MODULE__, run_id, test_case_id, pickle_id)

  def register_test_case(server, run_id, test_case_id, pickle_id) do
    GenServer.call(server, {:register_test_case, run_id, test_case_id, pickle_id})
  end

  @doc "Gets the pickle_id for a test_case_id."
  @impl ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour
  def get_test_case_pickle_id(run_id, test_case_id),
    do: get_test_case_pickle_id(__MODULE__, run_id, test_case_id)

  def get_test_case_pickle_id(server, run_id, test_case_id) do
    GenServer.call(server, {:get_test_case_pickle_id, run_id, test_case_id})
  end

  @doc "Stores a test case result."
  @impl ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour
  def add_test_case_result(run_id, test_case_started_id, result),
    do: add_test_case_result(__MODULE__, run_id, test_case_started_id, result)

  def add_test_case_result(server, run_id, test_case_started_id, result) do
    GenServer.call(server, {:add_test_case_result, run_id, test_case_started_id, result})
  end

  @doc "Retrieves a test case result."
  @impl ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour
  def get_test_case_result(run_id, test_case_started_id),
    do: get_test_case_result(__MODULE__, run_id, test_case_started_id)

  def get_test_case_result(server, run_id, test_case_started_id) do
    GenServer.call(server, {:get_test_case_result, run_id, test_case_started_id})
  end

  @doc "Lists all stored runs."
  def list_runs(server \\ __MODULE__) do
    GenServer.call(server, :list_runs)
  end

  @doc "Gets all test case results for a given run."
  def get_test_case_results(server \\ __MODULE__, run_id) do
    GenServer.call(server, {:get_test_case_results, run_id})
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    runs = :ets.new(:result_store_runs, [:set, :private])
    pickles = :ets.new(:result_store_pickles, [:set, :private])
    test_cases = :ets.new(:result_store_test_cases, [:set, :private])
    results = :ets.new(:result_store_results, [:set, :private])

    {:ok, %{runs: runs, pickles: pickles, test_cases: test_cases, results: results}}
  end

  @impl GenServer
  def handle_call({:create_run, run}, _from, state) do
    :ets.insert(state.runs, {run.id, run})
    {:reply, :ok, state}
  end

  def handle_call({:get_run, run_id}, _from, state) do
    case :ets.lookup(state.runs, run_id) do
      [{^run_id, run}] -> {:reply, {:ok, run}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:update_run, run_id, fun}, _from, state) do
    case :ets.lookup(state.runs, run_id) do
      [{^run_id, run}] ->
        updated = fun.(run)
        :ets.insert(state.runs, {run_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:register_pickle, run_id, pickle_id, pickle}, _from, state) do
    :ets.insert(state.pickles, {{run_id, pickle_id}, pickle})
    {:reply, :ok, state}
  end

  def handle_call({:get_pickle, run_id, pickle_id}, _from, state) do
    case :ets.lookup(state.pickles, {run_id, pickle_id}) do
      [{_, pickle}] -> {:reply, pickle, state}
      [] -> {:reply, nil, state}
    end
  end

  def handle_call({:register_test_case, run_id, test_case_id, pickle_id}, _from, state) do
    :ets.insert(state.test_cases, {{run_id, test_case_id}, pickle_id})
    {:reply, :ok, state}
  end

  def handle_call({:get_test_case_pickle_id, run_id, test_case_id}, _from, state) do
    case :ets.lookup(state.test_cases, {run_id, test_case_id}) do
      [{_, pickle_id}] -> {:reply, pickle_id, state}
      [] -> {:reply, nil, state}
    end
  end

  def handle_call({:add_test_case_result, run_id, test_case_started_id, result}, _from, state) do
    :ets.insert(state.results, {{run_id, test_case_started_id}, result})
    {:reply, :ok, state}
  end

  def handle_call({:get_test_case_result, run_id, test_case_started_id}, _from, state) do
    case :ets.lookup(state.results, {run_id, test_case_started_id}) do
      [{_, result}] -> {:reply, result, state}
      [] -> {:reply, nil, state}
    end
  end

  def handle_call(:list_runs, _from, state) do
    runs = :ets.tab2list(state.runs) |> Enum.map(fn {_id, run} -> run end)
    {:reply, runs, state}
  end

  def handle_call({:get_test_case_results, run_id}, _from, state) do
    results =
      :ets.match_object(state.results, {{run_id, :_}, :_})
      |> Enum.map(fn {_, result} -> result end)

    {:reply, results, state}
  end
end
