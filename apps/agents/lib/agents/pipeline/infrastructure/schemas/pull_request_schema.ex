defmodule Agents.Pipeline.Infrastructure.Schemas.PullRequestSchema do
  @moduledoc "Ecto schema for persisted internal pull requests."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["draft", "open", "in_review", "approved", "merged", "closed"]

  schema "pull_requests" do
    field(:number, :integer)
    field(:source_branch, :string)
    field(:target_branch, :string)
    field(:title, :string)
    field(:body, :string)
    field(:status, :string, default: "draft")
    field(:linked_ticket, :integer)
    field(:merged_at, :utc_datetime)
    field(:closed_at, :utc_datetime)

    has_many(:comments, Agents.Pipeline.Infrastructure.Schemas.ReviewCommentSchema,
      foreign_key: :pull_request_id
    )

    has_many(:reviews, Agents.Pipeline.Infrastructure.Schemas.ReviewSchema,
      foreign_key: :pull_request_id
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(pr, attrs) do
    pr
    |> cast(attrs, [
      :number,
      :source_branch,
      :target_branch,
      :title,
      :body,
      :status,
      :linked_ticket,
      :merged_at,
      :closed_at
    ])
    |> validate_required([:source_branch, :target_branch, :title])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:number)
  end
end
