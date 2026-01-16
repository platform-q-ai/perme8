defmodule Jarga.Notifications.Infrastructure.Schemas.NotificationSchema do
  @moduledoc """
  Ecto schema for storing user notifications.

  Supports multiple notification types (workspace_invitation, etc.)
  with type-specific data stored in the data field.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          user_id: Ecto.UUID.t(),
          type: String.t(),
          title: String.t(),
          body: String.t() | nil,
          data: map(),
          read: boolean(),
          read_at: DateTime.t() | nil,
          action_taken_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "notifications" do
    belongs_to(:user, Jarga.Accounts.Infrastructure.Schemas.UserSchema)

    field(:type, :string)
    field(:title, :string)
    field(:body, :string)
    field(:data, :map, default: %{})
    field(:read, :boolean, default: false)
    field(:read_at, :utc_datetime)
    field(:action_taken_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new notification.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :type, :title, :body, :data])
    |> validate_required([:user_id, :type, :title])
    |> validate_notification_type()
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for marking a notification as read.
  """
  def mark_read_changeset(notification, read_at \\ nil) do
    read_at = read_at || DateTime.utc_now() |> DateTime.truncate(:second)

    notification
    |> change(read: true, read_at: read_at)
  end

  @doc """
  Changeset for marking when action was taken on a notification.
  """
  def mark_action_taken_changeset(notification, action_taken_at \\ nil) do
    action_taken_at = action_taken_at || DateTime.utc_now() |> DateTime.truncate(:second)

    notification
    |> change(action_taken_at: action_taken_at)
  end

  # Supported notification types
  @valid_types ~w[workspace_invitation]

  defp validate_notification_type(changeset) do
    validate_inclusion(changeset, :type, @valid_types)
  end
end
