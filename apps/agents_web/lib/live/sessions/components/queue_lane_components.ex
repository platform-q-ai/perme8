defmodule AgentsWeb.SessionsLive.Components.QueueLaneComponents do
  @moduledoc """
  Snapshot-driven queue lane components.

  Renders queue lanes bottom-up from a QueueSnapshot struct.
  Processing lane at bottom, warm above, cold above warm,
  awaiting_feedback and retry_pending above.
  """
  use Phoenix.Component

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}
  alias Agents.Sessions.Domain.Policies.RetryPolicy

  @doc """
  Renders all queue lanes from a snapshot in bottom-up order.
  """
  attr(:snapshot, QueueSnapshot, required: true)
  attr(:active_container_id, :string, default: nil)

  def queue_lanes(assigns) do
    ~H"""
    <div data-testid="queue-lanes" class="flex flex-col-reverse gap-1">
      <.queue_lane
        :if={length(@snapshot.lanes.processing) > 0}
        lane={:processing}
        entries={@snapshot.lanes.processing}
        active_container_id={@active_container_id}
      />
      <.queue_lane
        :if={length(@snapshot.lanes.warm) > 0}
        lane={:warm}
        entries={@snapshot.lanes.warm}
        active_container_id={@active_container_id}
      />
      <.queue_lane
        :if={length(@snapshot.lanes.cold) > 0}
        lane={:cold}
        entries={@snapshot.lanes.cold}
        active_container_id={@active_container_id}
      />
      <.queue_lane
        :if={length(@snapshot.lanes.awaiting_feedback) > 0}
        lane={:awaiting_feedback}
        entries={@snapshot.lanes.awaiting_feedback}
        active_container_id={@active_container_id}
      />
      <.queue_lane
        :if={length(@snapshot.lanes.retry_pending) > 0}
        lane={:retry_pending}
        entries={@snapshot.lanes.retry_pending}
        active_container_id={@active_container_id}
      />
    </div>
    """
  end

  @doc """
  Renders a single queue lane with its entries.
  """
  attr(:lane, :atom, required: true)
  attr(:entries, :list, required: true)
  attr(:active_container_id, :string, default: nil)

  def queue_lane(assigns) do
    ~H"""
    <div data-testid={"lane-#{@lane}"} class="queue-lane">
      <div class="text-xs font-semibold text-base-content/60 px-2 py-1">
        {lane_label(@lane)} <span class="text-base-content/40">({length(@entries)})</span>
      </div>
      <.lane_entry
        :for={entry <- @entries}
        entry={entry}
        lane={@lane}
        active={entry.container_id == @active_container_id}
      />
    </div>
    """
  end

  @doc """
  Renders a single task entry within a lane.
  """
  attr(:entry, LaneEntry, required: true)
  attr(:lane, :atom, required: true)
  attr(:active, :boolean, default: false)

  def lane_entry(assigns) do
    ~H"""
    <div
      data-testid="task-card"
      data-task-id={@entry.task_id}
      class={[
        "px-2 py-1.5 text-sm cursor-pointer hover:bg-base-200 rounded",
        @active && "bg-primary/10 border-l-2 border-primary",
        @lane == :awaiting_feedback && "needs-attention bg-warning/10",
        @lane == :retry_pending && "bg-error/5"
      ]}
    >
      <div class="flex items-center gap-2">
        <.warm_state_indicator warm_state={@entry.warm_state} lane={@lane} />
        <span class="truncate flex-1">{truncate(@entry.instruction, 40)}</span>
        <.retry_badge :if={@entry.retry_count > 0} retry_count={@entry.retry_count} />
      </div>
    </div>
    """
  end

  @doc """
  Renders queue metadata from snapshot (concurrency, warm cache, slots).
  """
  attr(:snapshot, QueueSnapshot, required: true)

  def queue_metadata(assigns) do
    ~H"""
    <div data-testid="build-queue-panel" class="text-xs text-base-content/60 px-2 py-1 flex gap-3">
      <span>{@snapshot.metadata.running_count}/{@snapshot.metadata.concurrency_limit} running</span>
      <span :if={QueueSnapshot.available_slots(@snapshot) > 0}>
        {QueueSnapshot.available_slots(@snapshot)} slot{if QueueSnapshot.available_slots(@snapshot) !=
                                                             1,
                                                           do: "s"} available
      </span>
      <span :if={@snapshot.metadata.warm_cache_limit > 0}>
        Warm cache {length(@snapshot.lanes.warm)}/{@snapshot.metadata.warm_cache_limit}
      </span>
    </div>
    """
  end

  defp warm_state_indicator(%{lane: :processing} = assigns) do
    ~H"""
    <span data-testid="task-running-indicator" class="w-2 h-2 rounded-full bg-success animate-pulse" />
    """
  end

  defp warm_state_indicator(%{warm_state: :warm} = assigns) do
    ~H"""
    <span data-testid="task-warm-indicator" class="w-2 h-2 rounded-full bg-warning" title="Warm" />
    """
  end

  defp warm_state_indicator(%{warm_state: :warming} = assigns) do
    ~H"""
    <span
      data-testid="task-warming-indicator"
      class="w-2 h-2 rounded-full bg-warning/50 animate-pulse"
      title="Warming"
    />
    """
  end

  defp warm_state_indicator(%{warm_state: :cold} = assigns) do
    ~H"""
    <span data-testid="task-cold-indicator" class="w-2 h-2 rounded-full bg-base-300" title="Cold" />
    """
  end

  defp warm_state_indicator(assigns) do
    ~H"""
    <span class="w-2 h-2 rounded-full bg-base-300" />
    """
  end

  defp retry_badge(assigns) do
    assigns = assign(assigns, :max_retries, RetryPolicy.max_retries())

    ~H"""
    <span class="badge badge-xs badge-error">{@retry_count}/{@max_retries}</span>
    """
  end

  defp lane_label(:processing), do: "Processing"
  defp lane_label(:warm), do: "Warm"
  defp lane_label(:cold), do: "Cold"
  defp lane_label(:awaiting_feedback), do: "Awaiting Feedback"
  defp lane_label(:retry_pending), do: "Retry Pending"

  defp truncate(nil, _max), do: ""
  defp truncate(text, max) when byte_size(text) <= max, do: text
  defp truncate(text, max), do: String.slice(text, 0, max) <> "..."
end
