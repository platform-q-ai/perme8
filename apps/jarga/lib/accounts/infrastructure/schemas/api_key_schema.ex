defmodule Jarga.Accounts.Infrastructure.Schemas.ApiKeySchema do
  @moduledoc """
  Ecto schema for api_keys table.

  This schema represents the database table for API keys.
  Use `to_entity/1` to convert to the domain entity `ApiKey`.

  ## Fields

  - `id` - Unique identifier (binary_id)
  - `name` - Human-readable name for the API key
  - `description` - Optional description of the API key's purpose
  - `hashed_token` - Bcrypt hash of the API key token (never expose to clients)
  - `user_id` - Foreign key to users table (owner of the API key)
  - `workspace_access` - Array of workspace slugs this key can access
  - `is_active` - Boolean flag for soft delete (revoke sets to false)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp

  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          description: String.t() | nil,
          hashed_token: String.t(),
          user_id: String.t(),
          workspace_access: [String.t()],
          is_active: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "api_keys" do
    field(:name, :string)
    field(:description, :string)
    field(:hashed_token, :string)
    field(:workspace_access, {:array, :string}, default: [])
    field(:is_active, :boolean, default: true)

    belongs_to(:user, Jarga.Accounts.Infrastructure.Schemas.UserSchema)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for the API key schema.

  ## Examples

      iex> changeset = ApiKeySchema.changeset(%ApiKeySchema{}, %{name: "Test", hashed_token: "...", user_id: "..."})
      iex> changeset.valid?
      true

  """
  def changeset(%__MODULE__{} = api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :description, :hashed_token, :user_id, :workspace_access, :is_active])
    |> validate_required([:name, :hashed_token, :user_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_workspace_access()
  end

  @doc """
  Converts an infrastructure schema to a domain entity.

  ## Examples

      iex> entity = ApiKeySchema.to_entity(%ApiKeySchema{id: "123", name: "Test", ...})
      iex> entity.__struct__
      Jarga.Accounts.Domain.Entities.ApiKey

  """
  def to_entity(%__MODULE__{} = schema) do
    %Jarga.Accounts.Domain.Entities.ApiKey{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      hashed_token: schema.hashed_token,
      user_id: schema.user_id,
      workspace_access: schema.workspace_access || [],
      is_active: schema.is_active,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  # Validates that all workspace_access items are non-empty strings
  defp validate_workspace_access(changeset) do
    validate_change(changeset, :workspace_access, fn :workspace_access, workspace_access ->
      case Enum.all?(workspace_access, &validate_workspace_slug/1) do
        true -> []
        false -> [workspace_access: {"contains invalid workspace slugs", []}]
      end
    end)
  end

  # Validates a workspace slug is a non-empty string
  defp validate_workspace_slug(slug) when is_binary(slug) do
    String.length(slug) > 0
  end

  defp validate_workspace_slug(_), do: false
end
