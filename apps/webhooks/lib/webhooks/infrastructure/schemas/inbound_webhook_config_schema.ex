defmodule Webhooks.Infrastructure.Schemas.InboundWebhookConfigSchema do
  @moduledoc """
  Ecto schema for inbound webhook configurations.

  Maps to the `inbound_webhook_configs` database table.
  Each workspace can have at most one inbound config (unique constraint).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Webhooks.Domain.Entities.InboundWebhookConfig

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inbound_webhook_configs" do
    field(:workspace_id, :binary_id)
    field(:secret, :string)
    field(:is_active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating or updating an inbound webhook config."
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:workspace_id, :secret, :is_active])
    |> validate_required([:workspace_id, :secret])
    |> unique_constraint(:workspace_id)
  end

  @doc "Converts a schema struct to a domain InboundWebhookConfig entity."
  def to_entity(%__MODULE__{} = schema) do
    InboundWebhookConfig.from_schema(%{
      id: schema.id,
      workspace_id: schema.workspace_id,
      secret: schema.secret,
      is_active: schema.is_active,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end
end
