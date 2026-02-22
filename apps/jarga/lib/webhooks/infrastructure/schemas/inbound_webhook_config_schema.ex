defmodule Jarga.Webhooks.Infrastructure.Schemas.InboundWebhookConfigSchema do
  @moduledoc """
  Ecto schema for inbound webhook configuration (per-workspace).

  Stores the HMAC secret used to verify inbound webhook signatures.
  Each workspace has at most one inbound webhook configuration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inbound_webhook_configs" do
    # TODO: Encrypt inbound secret at rest (follow-up: add Cloak.Ecto or similar)
    field(:inbound_secret, :string)
    field(:workspace_id, :binary_id)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating an inbound webhook configuration.
  """
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:inbound_secret, :workspace_id])
    |> validate_required([:inbound_secret, :workspace_id])
    |> unique_constraint(:workspace_id)
  end
end
