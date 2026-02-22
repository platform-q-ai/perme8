defmodule Jarga.Webhooks.Domain.Entities.WebhookDelivery do
  @moduledoc """
  Domain entity representing an outbound webhook delivery attempt.

  Tracks the lifecycle of a single webhook delivery including
  HTTP response details, retry state, and exponential backoff timing.

  This is a pure data structure — no I/O, no Ecto, no side effects.
  """

  @type status :: String.t()

  @type t :: %__MODULE__{
          id: String.t() | nil,
          webhook_subscription_id: String.t() | nil,
          event_type: String.t() | nil,
          payload: map() | nil,
          status: status(),
          response_code: integer() | nil,
          response_body: String.t() | nil,
          attempts: non_neg_integer(),
          max_attempts: pos_integer(),
          next_retry_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct id: nil,
            webhook_subscription_id: nil,
            event_type: nil,
            payload: nil,
            status: "pending",
            response_code: nil,
            response_body: nil,
            attempts: 0,
            max_attempts: 5,
            next_retry_at: nil,
            inserted_at: nil,
            updated_at: nil

  @doc "Creates a new WebhookDelivery from an attrs map."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc "Alias for `new/1`."
  @spec from_map(map()) :: t()
  def from_map(attrs), do: new(attrs)
end
