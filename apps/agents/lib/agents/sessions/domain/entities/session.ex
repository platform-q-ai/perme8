defmodule Agents.Sessions.Domain.Entities.Session do
  @moduledoc """
  Pure domain entity representing a unified session lifecycle view.
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
    :queue_position,
    :queued_at,
    :started_at,
    :completed_at,
    lifecycle_state: :idle
  ]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @spec from_task(map()) :: t()
  def from_task(task) when is_map(task), do: from_task(task, %{})

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

  @spec valid_lifecycle_states() :: [lifecycle_state()]
  def valid_lifecycle_states, do: @valid_lifecycle_states

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
