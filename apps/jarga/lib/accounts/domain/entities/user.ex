defmodule Jarga.Accounts.Domain.Entities.User do
  @moduledoc """
  Pure domain entity for user accounts.

  This is a value object representing a user in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Jarga.Accounts.Infrastructure.Schemas.UserSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          email: String.t(),
          password: String.t() | nil,
          hashed_password: String.t() | nil,
          role: String.t() | nil,
          status: String.t() | nil,
          avatar_url: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          authenticated_at: DateTime.t() | nil,
          last_login: NaiveDateTime.t() | nil,
          date_created: NaiveDateTime.t() | nil,
          preferences: map()
        }

  defstruct [
    :id,
    :first_name,
    :last_name,
    :email,
    :password,
    :hashed_password,
    :role,
    :status,
    :avatar_url,
    :confirmed_at,
    :authenticated_at,
    :last_login,
    :date_created,
    preferences: %{}
  ]

  @doc """
  Creates a new User domain entity from attributes.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      first_name: schema.first_name,
      last_name: schema.last_name,
      email: schema.email,
      password: schema.password,
      hashed_password: schema.hashed_password,
      role: schema.role,
      status: schema.status,
      avatar_url: schema.avatar_url,
      confirmed_at: schema.confirmed_at,
      authenticated_at: schema.authenticated_at,
      last_login: schema.last_login,
      date_created: schema.date_created,
      preferences: schema.preferences || %{}
    }
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end

# Implement Inspect protocol to redact sensitive fields
defimpl Inspect, for: Jarga.Accounts.Domain.Entities.User do
  import Inspect.Algebra

  def inspect(user, opts) do
    # Redact password and hashed_password fields
    user_map =
      user
      |> Map.from_struct()
      |> Map.update(:password, nil, fn
        nil -> nil
        _password -> "**redacted**"
      end)
      |> Map.update(:hashed_password, nil, fn
        nil -> nil
        _hashed -> "**redacted**"
      end)

    concat(["#Jarga.Accounts.Domain.Entities.User<", to_doc(user_map, opts), ">"])
  end
end
