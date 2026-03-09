defmodule Agents.Sessions.Domain.Entities.Task do
  @moduledoc """
  Pure domain entity for coding tasks.

  This is a value object representing a task in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Agents.Sessions.Infrastructure.Schemas.TaskSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          instruction: String.t(),
          status: String.t(),
          lifecycle_state: String.t() | nil,
          image: String.t(),
          container_id: String.t() | nil,
          container_port: integer() | nil,
          session_id: String.t() | nil,
          user_id: String.t(),
          error: String.t() | nil,
          output: String.t() | nil,
          todo_items: map() | nil,
          session_summary: map() | nil,
          parent_task_id: String.t() | nil,
          pending_question: map() | nil,
          queue_position: integer() | nil,
          retry_count: non_neg_integer(),
          last_retry_at: DateTime.t() | nil,
          next_retry_at: DateTime.t() | nil,
          queued_at: DateTime.t() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :instruction,
    :container_id,
    :container_port,
    :lifecycle_state,
    :session_id,
    :user_id,
    :error,
    :output,
    :todo_items,
    :session_summary,
    :parent_task_id,
    :pending_question,
    :queue_position,
    :last_retry_at,
    :next_retry_at,
    :queued_at,
    :started_at,
    :completed_at,
    :inserted_at,
    :updated_at,
    retry_count: 0,
    status: "pending",
    image: "perme8-opencode"
  ]

  @doc """
  Creates a new Task domain entity from attributes.

  ## Examples

      iex> new(%{user_id: "user-123", instruction: "Write tests"})
      %Task{user_id: "user-123", instruction: "Write tests", status: "pending"}
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.

  ## Examples

      iex> from_schema(%TaskSchema{...})
      %Task{...}
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      instruction: schema.instruction,
      status: schema.status,
      lifecycle_state: Map.get(schema, :lifecycle_state),
      image: schema.image,
      container_id: schema.container_id,
      container_port: schema.container_port,
      session_id: schema.session_id,
      user_id: schema.user_id,
      error: schema.error,
      output: schema.output,
      todo_items: schema.todo_items,
      session_summary: schema.session_summary,
      parent_task_id: schema.parent_task_id,
      pending_question: schema.pending_question,
      queue_position: schema.queue_position,
      retry_count: schema.retry_count || 0,
      last_retry_at: schema.last_retry_at,
      next_retry_at: schema.next_retry_at,
      queued_at: schema.queued_at,
      started_at: schema.started_at,
      completed_at: schema.completed_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Returns list of valid status values.
  """
  def valid_statuses do
    [
      "pending",
      "starting",
      "running",
      "completed",
      "failed",
      "cancelled",
      "queued",
      "awaiting_feedback"
    ]
  end
end
