defmodule Identity.Infrastructure.Schemas.UserTokenSchema do
  @moduledoc """
  Ecto schema for user authentication tokens.

  This schema handles database persistence for tokens used in sessions, magic links,
  and email changes. All business logic for token building is in the TokenBuilder
  domain service.

  ## Architecture Note

  This is the infrastructure layer schema. Domain logic should work with the
  UserToken entity (plain struct) from `Identity.Domain.Entities.UserToken`.

  ## Token Types

  - Session tokens: `context: "session"` - Long-lived authentication
  - Login tokens: `context: "login"` - Magic link authentication
  - Change email tokens: `context: "change:old@email.com"` - Email verification

  ## Database Fields

  - `token` - Binary token (raw for session, hashed for email tokens)
  - `context` - Token purpose/type
  - `sent_to` - Email address (for email tokens)
  - `authenticated_at` - Authentication timestamp (for session tokens)
  - `user_id` - Associated user
  - `inserted_at` - Creation timestamp
  """

  use Ecto.Schema
  alias Identity.Domain.Entities.UserToken
  alias Identity.Infrastructure.Schemas.UserSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)
    field(:authenticated_at, :utc_datetime)
    belongs_to(:user, UserSchema, type: :binary_id)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Converts a UserTokenSchema to a UserToken domain entity.

  Returns nil if schema is nil.

  ## Examples

      iex> UserTokenSchema.to_entity(schema)
      %UserToken{id: "123", context: "session", ...}

      iex> UserTokenSchema.to_entity(nil)
      nil
  """
  def to_entity(nil), do: nil

  def to_entity(%__MODULE__{} = schema) do
    UserToken.from_schema(schema)
  end

  @doc """
  Converts a UserToken domain entity to a UserTokenSchema.

  Accepts both UserToken structs and UserTokenSchema structs (passthrough).
  Returns nil if input is nil.

  ## Examples

      iex> UserTokenSchema.from_entity(%UserToken{...})
      %UserTokenSchema{...}

      iex> UserTokenSchema.from_entity(%UserTokenSchema{...})
      %UserTokenSchema{...}

      iex> UserTokenSchema.from_entity(nil)
      nil
  """
  def from_entity(nil), do: nil

  def from_entity(%UserToken{} = entity) do
    %__MODULE__{
      id: entity.id,
      token: entity.token,
      context: entity.context,
      sent_to: entity.sent_to,
      authenticated_at: entity.authenticated_at,
      user_id: entity.user_id,
      inserted_at: entity.inserted_at
    }
  end

  # Passthrough for UserTokenSchema (already a schema)
  def from_entity(%__MODULE__{} = schema), do: schema
end
