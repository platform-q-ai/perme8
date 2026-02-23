defmodule Webhooks.Domain.Entities.Delivery do
  @moduledoc """
  Domain entity representing a webhook delivery attempt.

  Tracks the status, response, and retry state for a single
  outbound webhook dispatch.
  """

  @max_retries 5

  @type t :: %__MODULE__{
          id: String.t() | nil,
          subscription_id: String.t() | nil,
          event_type: String.t() | nil,
          payload: map() | nil,
          status: String.t(),
          response_code: integer() | nil,
          response_body: String.t() | nil,
          attempts: non_neg_integer(),
          max_attempts: non_neg_integer(),
          next_retry_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :subscription_id,
    :event_type,
    :payload,
    :response_code,
    :response_body,
    :next_retry_at,
    :inserted_at,
    :updated_at,
    status: "pending",
    attempts: 0,
    max_attempts: @max_retries
  ]

  @doc "Creates a new Delivery from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.get(attrs, :id),
      subscription_id: Map.get(attrs, :subscription_id),
      event_type: Map.get(attrs, :event_type),
      payload: Map.get(attrs, :payload),
      status: Map.get(attrs, :status, "pending"),
      response_code: Map.get(attrs, :response_code),
      response_body: Map.get(attrs, :response_body),
      attempts: Map.get(attrs, :attempts, 0),
      max_attempts: Map.get(attrs, :max_attempts, @max_retries),
      next_retry_at: Map.get(attrs, :next_retry_at),
      inserted_at: Map.get(attrs, :inserted_at),
      updated_at: Map.get(attrs, :updated_at)
    }
  end

  @doc "Converts an infrastructure schema map/struct to a domain entity."
  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    new(%{
      id: Map.get(schema, :id),
      subscription_id: Map.get(schema, :subscription_id),
      event_type: Map.get(schema, :event_type),
      payload: Map.get(schema, :payload),
      status: Map.get(schema, :status, "pending"),
      response_code: Map.get(schema, :response_code),
      response_body: Map.get(schema, :response_body),
      attempts: Map.get(schema, :attempts, 0),
      max_attempts: Map.get(schema, :max_attempts, @max_retries),
      next_retry_at: Map.get(schema, :next_retry_at),
      inserted_at: Map.get(schema, :inserted_at),
      updated_at: Map.get(schema, :updated_at)
    })
  end

  @doc "Returns true if the delivery was successful."
  @spec success?(t()) :: boolean()
  def success?(%__MODULE__{status: status}), do: status == "success"

  @doc "Returns true if the delivery has permanently failed."
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{status: status}), do: status == "failed"

  @doc "Returns true if the delivery is still pending."
  @spec pending?(t()) :: boolean()
  def pending?(%__MODULE__{status: status}), do: status == "pending"

  @doc "Returns true if the delivery has reached the maximum number of retry attempts."
  @spec max_retries_reached?(t()) :: boolean()
  def max_retries_reached?(%__MODULE__{attempts: attempts, max_attempts: max_attempts}) do
    attempts >= max_attempts
  end
end
