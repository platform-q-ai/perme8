defmodule Jarga.Agents.Infrastructure.Agent do
  @moduledoc """
  Schema for user-owned AI agents.

  Agents belong to users and can be shared across multiple workspaces.
  Each agent has a visibility setting (PRIVATE or SHARED) that controls
  who can see and use the agent.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Jarga.Accounts.User

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          user_id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t() | nil,
          system_prompt: String.t() | nil,
          model: String.t() | nil,
          temperature: float(),
          visibility: String.t(),
          enabled: boolean(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @valid_visibilities ~w(PRIVATE SHARED)

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "agents" do
    field(:name, :string)
    field(:description, :string)
    field(:system_prompt, :string)
    field(:model, :string)
    field(:temperature, :float, default: 0.7)
    field(:input_token_cost, :decimal)
    field(:cached_input_token_cost, :decimal)
    field(:output_token_cost, :decimal)
    field(:cached_output_token_cost, :decimal)
    field(:visibility, :string, default: "PRIVATE")
    field(:enabled, :boolean, default: true)

    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for an agent.

  ## Required Fields
  - user_id
  - name

  ## Optional Fields
  - description
  - system_prompt
  - model
  - temperature (default: 0.7, range: 0.0 - 2.0)
  - visibility (default: PRIVATE, values: PRIVATE | SHARED)
  - enabled (default: true)
  """
  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [
      :user_id,
      :name,
      :description,
      :system_prompt,
      :model,
      :temperature,
      :input_token_cost,
      :cached_input_token_cost,
      :output_token_cost,
      :cached_output_token_cost,
      :visibility,
      :enabled
    ])
    |> validate_required([:user_id, :name])
    |> validate_inclusion(:visibility, @valid_visibilities)
    |> validate_number(:temperature, greater_than_or_equal_to: 0, less_than_or_equal_to: 2)
    |> foreign_key_constraint(:user_id)
  end
end
