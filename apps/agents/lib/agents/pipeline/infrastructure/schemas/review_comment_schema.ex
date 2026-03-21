defmodule Agents.Pipeline.Infrastructure.Schemas.ReviewCommentSchema do
  @moduledoc "Ecto schema for persisted internal PR comments."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pr_comments" do
    field(:author_id, :string)
    field(:body, :string)
    field(:path, :string)
    field(:line, :integer)
    field(:resolved, :boolean, default: false)
    field(:resolved_at, :utc_datetime)
    field(:resolved_by, :string)

    belongs_to(:pull_request, Agents.Pipeline.Infrastructure.Schemas.PullRequestSchema)

    belongs_to(:parent_comment, __MODULE__,
      foreign_key: :parent_comment_id,
      references: :id,
      type: :binary_id
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :pull_request_id,
      :author_id,
      :body,
      :path,
      :line,
      :parent_comment_id,
      :resolved,
      :resolved_at,
      :resolved_by
    ])
    |> validate_required([:pull_request_id, :author_id, :body])
    |> foreign_key_constraint(:pull_request_id)
    |> foreign_key_constraint(:parent_comment_id)
  end
end
