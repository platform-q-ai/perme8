defmodule Agents.Pipeline.Domain.Entities.PullRequestTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.PullRequest

  describe "new/1" do
    test "builds entity with defaults" do
      pr =
        PullRequest.new(%{
          number: 42,
          source_branch: "feature/internal-pr",
          target_branch: "main",
          title: "Internal PR"
        })

      assert pr.number == 42
      assert pr.status == "draft"
      assert pr.comments == []
      assert pr.reviews == []
    end
  end

  describe "from_schema/1" do
    test "converts schema-like struct and nested associations" do
      schema = %{
        __struct__: Agents.Pipeline.Infrastructure.Schemas.PullRequestSchema,
        id: "pr-id",
        number: 12,
        source_branch: "feature/a",
        target_branch: "main",
        title: "Title",
        body: "Body",
        status: "in_review",
        linked_ticket: 502,
        inserted_at: ~U[2026-03-21 12:00:00Z],
        updated_at: ~U[2026-03-21 12:10:00Z],
        comments: [
          %{
            __struct__: Agents.Pipeline.Infrastructure.Schemas.ReviewCommentSchema,
            id: "c1",
            pull_request_id: "pr-id",
            author_id: "u1",
            body: "nit",
            path: "lib/a.ex",
            line: 10,
            inserted_at: ~U[2026-03-21 12:01:00Z],
            updated_at: ~U[2026-03-21 12:01:00Z]
          }
        ],
        reviews: [
          %{
            __struct__: Agents.Pipeline.Infrastructure.Schemas.ReviewSchema,
            id: "r1",
            pull_request_id: "pr-id",
            author_id: "u2",
            event: "approve",
            body: "looks good",
            submitted_at: ~U[2026-03-21 12:02:00Z],
            inserted_at: ~U[2026-03-21 12:02:00Z],
            updated_at: ~U[2026-03-21 12:02:00Z]
          }
        ]
      }

      pr = PullRequest.from_schema(schema)

      assert pr.id == "pr-id"
      assert pr.status == "in_review"
      assert pr.linked_ticket == 502
      assert Enum.map(pr.comments, & &1.body) == ["nit"]
      assert Enum.map(pr.reviews, & &1.event) == ["approve"]
    end
  end

  describe "valid_statuses/0" do
    test "returns supported internal PR states" do
      assert PullRequest.valid_statuses() == [
               "draft",
               "open",
               "in_review",
               "approved",
               "merged",
               "closed"
             ]
    end
  end
end
