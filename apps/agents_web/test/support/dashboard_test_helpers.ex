defmodule AgentsWeb.DashboardTestHelpers do
  @moduledoc """
  Shared test helpers for dashboard LiveView integration tests.

  Provides `FakeTaskRunner` (a GenServer that registers in the TaskRegistry)
  and `send_queue_state/3` (builds a QueueSnapshot from a legacy map and
  delivers it to a LiveView process).
  """

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}

  defmodule FakeTaskRunner do
    @moduledoc false
    use GenServer

    def start_link(task_id) do
      GenServer.start_link(__MODULE__, task_id)
    end

    @impl true
    def init(task_id) do
      Registry.register(Agents.Sessions.TaskRegistry, task_id, %{})
      {:ok, %{task_id: task_id}}
    end

    @impl true
    def handle_call({:send_message, _message, _opts}, _from, state) do
      {:reply, :ok, state}
    end

    @impl true
    def handle_call({:send_message, _message}, _from, state) do
      {:reply, :ok, state}
    end

    @impl true
    def handle_call({:answer_question, _request_id, _answers, _message}, _from, state) do
      {:reply, :ok, state}
    end

    @impl true
    def handle_call({:answer_question, _request_id, _answers}, _from, state) do
      {:reply, :ok, state}
    end
  end

  @doc """
  Converts a legacy queue state map to a `QueueSnapshot` and sends it as a
  `:queue_snapshot` message to the LiveView process.

  Handles `warm_cache_limit` (tasks within the limit go to warm lane),
  `warm_task_ids` (explicit warm tasks), and `warming_task_ids` (tasks
  currently being warmed, shown with warming animation).
  """
  def send_queue_state(lv, user_id, queue_state) do
    running_count = Map.get(queue_state, :running, 0)
    concurrency_limit = Map.get(queue_state, :concurrency_limit, 2)
    warm_cache_limit = Map.get(queue_state, :warm_cache_limit, 0)
    queued = Map.get(queue_state, :queued, [])
    awaiting_feedback = Map.get(queue_state, :awaiting_feedback, [])
    warming_task_ids = Map.get(queue_state, :warming_task_ids, [])

    # Split queued tasks: first warm_cache_limit go to warm lane, rest to cold
    queued_ids =
      Enum.map(queued, fn item ->
        if is_map(item), do: Map.get(item, :id), else: item
      end)

    {warm_ids, cold_ids} = Enum.split(queued_ids, warm_cache_limit)

    warm_entries =
      Enum.map(warm_ids, fn id ->
        ws = if id in warming_task_ids, do: :warming, else: :warm

        LaneEntry.new(%{
          task_id: id,
          instruction: "",
          status: "queued",
          lane: :warm,
          warm_state: ws
        })
      end)

    cold_entries =
      Enum.map(cold_ids, fn id ->
        LaneEntry.new(%{
          task_id: id,
          instruction: "",
          status: "queued",
          lane: :cold,
          warm_state: :cold
        })
      end)

    af_entries =
      Enum.map(awaiting_feedback, fn item ->
        id = if is_map(item), do: Map.get(item, :id), else: item

        LaneEntry.new(%{
          task_id: id,
          instruction: "",
          status: "awaiting_feedback",
          lane: :awaiting_feedback,
          warm_state: :cold
        })
      end)

    snapshot =
      QueueSnapshot.new(%{
        user_id: user_id,
        lanes: %{
          processing: [],
          warm: warm_entries,
          cold: cold_entries,
          awaiting_feedback: af_entries,
          retry_pending: []
        },
        metadata: %{
          concurrency_limit: concurrency_limit,
          running_count: running_count,
          warm_cache_limit: warm_cache_limit
        }
      })

    send(lv.pid, {:queue_snapshot, user_id, snapshot})
  end
end
