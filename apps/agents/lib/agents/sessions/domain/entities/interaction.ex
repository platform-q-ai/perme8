defmodule Agents.Sessions.Domain.Entities.Interaction do
  @moduledoc """
  Pure domain entity representing an interaction within a session.

  Interactions capture all human-AI communication: questions, answers,
  instructions, and queued responses. They replace the ephemeral
  `pending_question` field on tasks with durable, typed records.
  """

  @valid_types [:question, :answer, :instruction, :queued_response]
  @valid_directions [:inbound, :outbound]
  @valid_statuses [:pending, :delivered, :expired, :cancelled, :rolled_back, :timed_out]

  @type interaction_type :: :question | :answer | :instruction | :queued_response
  @type direction :: :inbound | :outbound
  @type interaction_status ::
          :pending | :delivered | :expired | :cancelled | :rolled_back | :timed_out

  @type t :: %__MODULE__{
          id: String.t() | nil,
          session_id: String.t() | nil,
          task_id: String.t() | nil,
          type: interaction_type() | nil,
          direction: direction() | nil,
          payload: map(),
          correlation_id: String.t() | nil,
          status: interaction_status(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :session_id,
    :task_id,
    :type,
    :direction,
    :correlation_id,
    :inserted_at,
    :updated_at,
    payload: %{},
    status: :pending
  ]

  @doc "Creates a new Interaction from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @doc "Converts from a schema struct to a domain entity."
  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    new(%{
      id: schema.id,
      session_id: schema.session_id,
      task_id: schema.task_id,
      type: to_atom(schema.type),
      direction: to_atom(schema.direction),
      payload: schema.payload || %{},
      correlation_id: schema.correlation_id,
      status: to_atom(schema.status),
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end

  # Type predicates
  def question?(%__MODULE__{type: :question}), do: true
  def question?(_), do: false

  def answer?(%__MODULE__{type: :answer}), do: true
  def answer?(_), do: false

  def instruction?(%__MODULE__{type: :instruction}), do: true
  def instruction?(_), do: false

  def queued_response?(%__MODULE__{type: :queued_response}), do: true
  def queued_response?(_), do: false

  # Status predicates
  def pending?(%__MODULE__{status: :pending}), do: true
  def pending?(_), do: false

  def delivered?(%__MODULE__{status: :delivered}), do: true
  def delivered?(_), do: false

  def expired?(%__MODULE__{status: :expired}), do: true
  def expired?(_), do: false

  def valid_types, do: @valid_types
  def valid_directions, do: @valid_directions
  def valid_statuses, do: @valid_statuses

  defp to_atom(val) when is_atom(val), do: val
  defp to_atom(val) when is_binary(val), do: String.to_existing_atom(val)
  defp to_atom(_), do: nil
end
