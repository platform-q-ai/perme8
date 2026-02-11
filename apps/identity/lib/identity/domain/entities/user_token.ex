defmodule Identity.Domain.Entities.UserToken do
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
  Converts an Ecto schema (or any map/struct with matching fields) to a UserToken domain entity.

  Returns nil if input is nil.

  ## Examples

      iex> from_schema(%{id: "123", token: <<1,2,3>>, context: "session", ...})
      %UserToken{id: "123", token: <<1,2,3>>, context: "session", ...}

      iex> from_schema(nil)
      nil
  """
  def from_schema(nil), do: nil

  def from_schema(schema) do
    %__MODULE__{
      id: Map.get(schema, :id),
      token: Map.get(schema, :token),
      context: Map.get(schema, :context),
      sent_to: Map.get(schema, :sent_to),
      authenticated_at: Map.get(schema, :authenticated_at),
      user_id: Map.get(schema, :user_id),
      inserted_at: Map.get(schema, :inserted_at)
    }
  end
end
