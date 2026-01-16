defmodule Jarga.Accounts.Domain.Entities.UserToken do
  @moduledoc """
  Pure domain entity for user authentication tokens.

  This is a plain struct with NO Ecto dependencies, following Clean Architecture principles.
  Token building logic is delegated to TokenBuilder domain service.

  ## Fields

  - `id` - Token identifier (binary_id)
  - `token` - Token value (binary)
  - `context` - Token context ("session", "login", "change:email")
  - `sent_to` - Email address where token was sent
  - `authenticated_at` - Timestamp when user was authenticated (session tokens)
  - `user_id` - Associated user ID
  - `inserted_at` - When token was created
  """

  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema

  @type t :: %__MODULE__{
          id: String.t() | nil,
          token: binary() | nil,
          context: String.t() | nil,
          sent_to: String.t() | nil,
          authenticated_at: DateTime.t() | nil,
          user_id: String.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :token,
    :context,
    :sent_to,
    :authenticated_at,
    :user_id,
    :inserted_at
  ]

  @doc """
  Converts a UserTokenSchema (Ecto schema) to a UserToken (domain entity).

  Returns nil if schema is nil.
  """
  def from_schema(nil), do: nil

  def from_schema(%UserTokenSchema{} = schema) do
    %__MODULE__{
      id: schema.id,
      token: schema.token,
      context: schema.context,
      sent_to: schema.sent_to,
      authenticated_at: schema.authenticated_at,
      user_id: schema.user_id,
      inserted_at: schema.inserted_at
    }
  end
end
