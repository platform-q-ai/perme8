defmodule Identity.Infrastructure.Schemas.UserSchema do
  @moduledoc """
  Ecto schema for user accounts.
  This is the infrastructure representation that handles database persistence.

  For the pure domain entity, see Identity.Domain.Entities.User.
  """

  @behaviour Identity.Application.Behaviours.UserSchemaBehaviour

  use Ecto.Schema
  import Ecto.Changeset

  alias Identity.Domain.Entities.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:role, :string)
    field(:status, :string)
    field(:avatar_url, :string)
    field(:confirmed_at, :utc_datetime)
    field(:authenticated_at, :utc_datetime, virtual: true)
    field(:last_login, :naive_datetime)
    field(:date_created, :naive_datetime)
    field(:preferences, :map, default: %{})

    # Legacy timestamp fields - not using standard inserted_at/updated_at
    # timestamps(type: :utc_datetime)
  end

  @doc """
  Converts a domain entity to a schema struct.
  If already a schema, returns it unchanged.
  """
  def to_schema(%__MODULE__{} = schema), do: schema

  def to_schema(%User{} = user) do
    %__MODULE__{
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      password: user.password,
      hashed_password: user.hashed_password,
      role: user.role,
      status: user.status,
      avatar_url: user.avatar_url,
      confirmed_at: user.confirmed_at,
      authenticated_at: user.authenticated_at,
      last_login: user.last_login,
      date_created: user.date_created,
      preferences: user.preferences
    }
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.
  Accepts either a schema struct or a domain entity (which will be converted).

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  @impl true
  def email_changeset(user_or_schema, attrs, opts \\ [])

  def email_changeset(%User{} = user, attrs, opts) do
    user
    |> to_schema()
    |> email_changeset(attrs, opts)
  end

  def email_changeset(%__MODULE__{} = schema, attrs, opts) do
    schema
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)
      |> update_change(:email, &String.downcase/1)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  Accepts either a schema struct or a domain entity (which will be converted).

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
      
  Note: Password hashing is handled by the infrastructure layer, not in this changeset.
  """
  @impl true
  def registration_changeset(user_or_schema, attrs, opts \\ [])

  def registration_changeset(%User{} = user, attrs, opts) do
    user
    |> to_schema()
    |> registration_changeset(attrs, opts)
  end

  def registration_changeset(%__MODULE__{} = schema, attrs, opts) do
    schema
    |> cast(attrs, [:email, :password, :first_name, :last_name])
    |> validate_required([:first_name, :last_name])
    |> put_change(:date_created, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
    |> put_change(:status, "active")
    |> validate_email(opts)
    |> validate_password_format(opts)
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  Accepts either a schema struct or a domain entity (which will be converted).

  Note: Password hashing is handled by the infrastructure layer, not in this changeset.
  """
  @impl true
  def password_changeset(user_or_schema, attrs, opts \\ [])

  def password_changeset(%User{} = user, attrs, opts) do
    user
    |> to_schema()
    |> password_changeset(attrs, opts)
  end

  def password_changeset(%__MODULE__{} = schema, attrs, opts) do
    schema
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password_format(opts)
  end

  # Password format validation only - NO hashing
  # Password hashing is handled by the infrastructure layer (PasswordService)
  defp validate_password_format(changeset, _opts) do
    password = get_change(changeset, :password)

    if password do
      changeset
      |> validate_length(:password, min: 12, max: 72)

      # Examples of additional password validation:
      # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
      # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
      # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  Accepts either a schema struct or a domain entity (which will be converted).
  """
  @impl true
  def confirm_changeset(user_or_schema)

  def confirm_changeset(%User{} = user) do
    user
    |> to_schema()
    |> confirm_changeset()
  end

  def confirm_changeset(%__MODULE__{} = schema) do
    now = DateTime.utc_now(:second)

    schema
    |> change()
    |> force_change(:confirmed_at, now)
  end
end
