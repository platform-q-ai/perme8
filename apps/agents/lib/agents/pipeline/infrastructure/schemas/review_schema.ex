defmodule Agents.Pipeline.Infrastructure.Schemas.ReviewSchema do
  @moduledoc "Ecto schema for persisted internal PR reviews."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @events ["approve", "request_changes", "comment"]

  schema "pr_reviews" do
    field(:author_id, :string)
    field(:event, :string)
    field(:body, :string)
    field(:submitted_at, :utc_datetime)

    belongs_to(:pull_request, Agents.Pipeline.Infrastructure.Schemas.PullRequestSchema)

    timestamps(type: :utc_datetime)
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:pull_request_id, :author_id, :event, :body, :submitted_at])
    |> validate_required([:pull_request_id, :author_id, :event])
    |> validate_inclusion(:event, @events)
    |> foreign_key_constraint(:pull_request_id)
  end
end
