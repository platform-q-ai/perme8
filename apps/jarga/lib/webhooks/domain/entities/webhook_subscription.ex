defmodule Jarga.Webhooks.Domain.Entities.WebhookSubscription do
  @moduledoc """
  Domain entity representing an outbound webhook subscription.

  A webhook subscription defines an HTTP endpoint that receives
  signed POST requests when matching domain events occur.

  This is a pure data structure — no I/O, no Ecto, no side effects.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          url: String.t() | nil,
          secret: String.t() | nil,
          event_types: [String.t()],
          is_active: boolean(),
          workspace_id: String.t() | nil,
          created_by_id: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct id: nil,
            url: nil,
            secret: nil,
            event_types: [],
            is_active: true,
            workspace_id: nil,
            created_by_id: nil,
            inserted_at: nil,
            updated_at: nil

  @doc "Creates a new WebhookSubscription from an attrs map."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc "Alias for `new/1`."
  @spec from_map(map()) :: t()
  def from_map(attrs), do: new(attrs)
end
