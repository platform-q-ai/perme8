defmodule Jarga.Webhooks.Domain.Entities.InboundWebhook do
  @moduledoc """
  Domain entity representing an inbound webhook request.

  Records the receipt of an external webhook payload including
  signature validation status and handler processing result.

  This is a pure data structure — no I/O, no Ecto, no side effects.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t() | nil,
          event_type: String.t() | nil,
          payload: map() | nil,
          source_ip: String.t() | nil,
          signature_valid: boolean(),
          handler_result: String.t() | nil,
          received_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  defstruct id: nil,
            workspace_id: nil,
            event_type: nil,
            payload: nil,
            source_ip: nil,
            signature_valid: false,
            handler_result: nil,
            received_at: nil,
            inserted_at: nil

  @doc "Creates a new InboundWebhook from an attrs map."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc "Alias for `new/1`."
  @spec from_map(map()) :: t()
  def from_map(attrs), do: new(attrs)
end
