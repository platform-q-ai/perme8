defmodule Agents.Pipeline.Domain.Entities.PullRequest do
  @moduledoc "Pure domain entity for internal pull requests."

  alias Agents.Pipeline.Domain.Entities.{Review, ReviewComment}

  @statuses ["draft", "open", "in_review", "approved", "merged", "closed"]

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          number: integer() | nil,
          source_branch: String.t() | nil,
          target_branch: String.t() | nil,
          title: String.t() | nil,
          body: String.t() | nil,
          status: String.t(),
          linked_ticket: integer() | nil,
          merged_at: DateTime.t() | nil,
          closed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          comments: [ReviewComment.t()],
          reviews: [Review.t()]
        }

  defstruct [
    :id,
    :number,
    :source_branch,
    :target_branch,
    :title,
    :body,
    :linked_ticket,
    :merged_at,
    :closed_at,
    :inserted_at,
    :updated_at,
    status: "draft",
    comments: [],
    reviews: []
  ]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @spec valid_statuses() :: [String.t()]
  def valid_statuses, do: @statuses

  @spec from_schema(struct()) :: t()
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      number: schema.number,
      source_branch: schema.source_branch,
      target_branch: schema.target_branch,
      title: schema.title,
      body: schema.body,
      status: schema.status || "draft",
      linked_ticket: schema.linked_ticket,
      merged_at: Map.get(schema, :merged_at),
      closed_at: Map.get(schema, :closed_at),
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at,
      comments: convert_comments(Map.get(schema, :comments, [])),
      reviews: convert_reviews(Map.get(schema, :reviews, []))
    }
  end

  @spec group_comment_threads([ReviewComment.t()]) :: [map()]
  def group_comment_threads(comments) when is_list(comments) do
    comments_by_id = Map.new(comments, &{&1.id, &1})

    roots =
      Enum.filter(comments, fn comment ->
        is_nil(comment.parent_comment_id) or
          !Map.has_key?(comments_by_id, comment.parent_comment_id)
      end)

    roots
    |> Enum.sort_by(&sort_key/1)
    |> Enum.map(fn root ->
      replies =
        comments
        |> Enum.filter(&(&1.parent_comment_id == root.id))
        |> Enum.sort_by(&sort_key/1)

      %{
        id: root.id,
        path: root.path,
        line: root.line,
        resolved: root.resolved,
        resolved_at: root.resolved_at,
        resolved_by: root.resolved_by,
        comments: [root | replies]
      }
    end)
  end

  def group_comment_threads(_), do: []

  defp sort_key(comment) do
    timestamp = comment.inserted_at || ~U[1970-01-01 00:00:00Z]
    {DateTime.to_unix(timestamp, :microsecond), comment.id || ""}
  end

  defp convert_comments(%Ecto.Association.NotLoaded{}), do: []

  defp convert_comments(comments) when is_list(comments),
    do: Enum.map(comments, &ReviewComment.from_schema/1)

  defp convert_comments(_), do: []

  defp convert_reviews(%Ecto.Association.NotLoaded{}), do: []

  defp convert_reviews(reviews) when is_list(reviews),
    do: Enum.map(reviews, &Review.from_schema/1)

  defp convert_reviews(_), do: []
end
