defmodule Agents.Pipeline.Domain.Entities.ReviewCommentTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.ReviewComment

  describe "new/1" do
    test "builds entity with defaults" do
      comment =
        ReviewComment.new(%{
          body: "Please extract this helper",
          author_id: "user-1"
        })

      assert comment.body == "Please extract this helper"
      assert comment.author_id == "user-1"
      assert comment.resolved == false
    end
  end

  describe "from_schema/1" do
    test "converts schema-like struct including thread fields" do
      schema = %{
        __struct__: Agents.Pipeline.Infrastructure.Schemas.ReviewCommentSchema,
        id: "comment-1",
        pull_request_id: "pr-1",
        author_id: "user-1",
        body: "nit: rename this",
        path: "lib/demo.ex",
        line: 12,
        parent_comment_id: "comment-root",
        resolved: true,
        resolved_at: ~U[2026-03-22 12:00:00Z],
        resolved_by: "user-2",
        inserted_at: ~U[2026-03-22 11:00:00Z],
        updated_at: ~U[2026-03-22 12:00:00Z]
      }

      comment = ReviewComment.from_schema(schema)

      assert comment.id == "comment-1"
      assert comment.pull_request_id == "pr-1"
      assert comment.parent_comment_id == "comment-root"
      assert comment.resolved == true
      assert comment.resolved_by == "user-2"
      assert comment.resolved_at == ~U[2026-03-22 12:00:00Z]
    end
  end
end
