defmodule Agents.Sessions.Domain.Entities.Session do
  @moduledoc """
  Pure domain entity representing a unified session lifecycle view.

  Tracks both lifecycle state transitions and SDK event state: message counts,
  streaming activity, active tool calls, error classification, permission
  context, retry metadata, file edits, compaction, and session metadata.
  """

  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy

  @valid_lifecycle_states [
    :idle,
    :queued_cold,
    :queued_warm,
    :warming,
    :pending,
    :starting,
    :running,
    :awaiting_feedback,
    :completed,
    :failed,
    :cancelled
  ]

  @type lifecycle_state ::
          :idle
          | :queued_cold
          | :queued_warm
          | :warming
          | :pending
          | :starting
          | :running
          | :awaiting_feedback
          | :completed
          | :failed
          | :cancelled

  @type t :: %__MODULE__{
          task_id: String.t() | nil,
          user_id: String.t() | nil,
          lifecycle_state: lifecycle_state(),
          status: String.t() | nil,
          container_id: String.t() | nil,
          container_port: integer() | nil,
          session_id: String.t() | nil,
          instruction: String.t() | nil,
          error: String.t() | nil,
          error_category: atom() | nil,
          error_recoverable: boolean() | nil,
          permission_context: map() | nil,
          retry_attempt: non_neg_integer(),
          retry_message: String.t() | nil,
          retry_next_at: String.t() | nil,
          message_count: non_neg_integer(),
          streaming_active: boolean(),
          active_tool_calls: non_neg_integer(),
          file_edits: [String.t()],
          compacted: boolean(),
          sdk_session_title: String.t() | nil,
          sdk_share_status: String.t() | nil,
          last_event_id: String.t() | nil,
          queue_position: integer() | nil,
          queued_at: DateTime.t() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil
        }

  defstruct [
    :task_id,
    :user_id,
    :status,
    :container_id,
    :container_port,
    :session_id,
    :instruction,
    :error,
    :error_category,
    :error_recoverable,
    :permission_context,
    :retry_message,
    :retry_next_at,
    :sdk_session_title,
    :sdk_share_status,
    :last_event_id,
    :queue_position,
    :queued_at,
    :started_at,
    :completed_at,
    message_count: 0,
    streaming_active: false,
    active_tool_calls: 0,
    retry_attempt: 0,
    file_edits: [],
    compacted: false,
    lifecycle_state: :idle
  ]

  @doc "Creates a new Session entity from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @doc "Updates a Session entity by merging the provided attributes."
  @spec update(t(), map()) :: t()
  def update(session, attrs), do: struct(session, attrs)

  @doc "Increments the tracked message count by one."
  @spec track_message(t()) :: t()
  def track_message(session), do: %{session | message_count: session.message_count + 1}

  @doc "Decrements the tracked message count by one, with a floor of zero."
  @spec remove_message(t()) :: t()
  def remove_message(session), do: %{session | message_count: max(session.message_count - 1, 0)}

  @doc "Marks the session as actively streaming."
  @spec start_streaming(t()) :: t()
  def start_streaming(session), do: %{session | streaming_active: true}

  @doc "Marks the session as no longer actively streaming."
  @spec stop_streaming(t()) :: t()
  def stop_streaming(session), do: %{session | streaming_active: false}

  @doc "Increments the count of active tool calls by one."
  @spec increment_tool_calls(t()) :: t()
  def increment_tool_calls(session),
    do: %{session | active_tool_calls: session.active_tool_calls + 1}

  @doc "Decrements active tool calls by one, with a floor of zero."
  @spec decrement_tool_calls(t()) :: t()
  def decrement_tool_calls(session),
    do: %{session | active_tool_calls: max(session.active_tool_calls - 1, 0)}

  @doc "Records a file path edit once, deduplicated by path."
  @spec record_file_edit(t(), String.t()) :: t()
  def record_file_edit(session, path) do
    if path in session.file_edits do
      session
    else
      %{session | file_edits: [path | session.file_edits]}
    end
  end

  @doc "Marks the session as compacted."
  @spec mark_compacted(t()) :: t()
  def mark_compacted(session), do: %{session | compacted: true}

  @doc "Builds a Session from a task map, deriving the lifecycle state."
  @spec from_task(map()) :: t()
  def from_task(task) when is_map(task), do: from_task(task, %{})

  @doc "Builds a Session from a task map merged with additional metadata."
  @spec from_task(map(), map()) :: t()
  def from_task(task, metadata) when is_map(task) and is_map(metadata) do
    attrs = Map.merge(task, metadata)

    lifecycle_state =
      SessionLifecyclePolicy.derive(%{
        status: value(attrs, :status),
        container_id: value(attrs, :container_id),
        container_port: value(attrs, :container_port)
      })

    new(%{
      task_id: value(attrs, :task_id) || value(attrs, :id),
      user_id: value(attrs, :user_id),
      lifecycle_state: lifecycle_state,
      status: value(attrs, :status),
      container_id: value(attrs, :container_id),
      container_port: value(attrs, :container_port),
      session_id: value(attrs, :session_id),
      instruction: value(attrs, :instruction),
      error: value(attrs, :error),
      queue_position: value(attrs, :queue_position),
      queued_at: value(attrs, :queued_at),
      started_at: value(attrs, :started_at),
      completed_at: value(attrs, :completed_at)
    })
  end

  @doc "Returns the list of all valid lifecycle states."
  @spec valid_lifecycle_states() :: [lifecycle_state()]
  def valid_lifecycle_states, do: @valid_lifecycle_states

  @doc "Returns a human-readable display name for a lifecycle state."
  @spec display_name(lifecycle_state()) :: String.t()
  def display_name(:queued_cold), do: "Queued (cold)"
  def display_name(:queued_warm), do: "Queued (warm)"
  def display_name(:warming), do: "Warming up"
  def display_name(:starting), do: "Starting"
  def display_name(:running), do: "Running"
  def display_name(:awaiting_feedback), do: "Awaiting feedback"
  def display_name(:completed), do: "Completed"
  def display_name(:failed), do: "Failed"
  def display_name(:cancelled), do: "Cancelled"
  def display_name(:idle), do: "Idle"
  def display_name(:pending), do: "Pending"

  defp value(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} -> val
      :error -> Map.get(map, Atom.to_string(key))
    end
  end
end
