defmodule Agents.Pipeline.Domain.Entities.ReviewTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.Review

  describe "new/1" do
    test "builds entity" do
      review =
        Review.new(%{
          author_id: "user-1",
          event: "approve",
          body: "Looks good"
        })

      assert review.author_id == "user-1"
      assert review.event == "approve"
      assert review.body == "Looks good"
    end
  end

  describe "from_schema/1" do
    test "converts schema-like struct" do
      schema = %{
        __struct__: Agents.Pipeline.Infrastructure.Schemas.ReviewSchema,
        id: "review-1",
        pull_request_id: "pr-1",
        author_id: "user-1",
        event: "request_changes",
        body: "Please add coverage",
        submitted_at: ~U[2026-03-22 12:30:00Z],
        inserted_at: ~U[2026-03-22 12:30:00Z],
        updated_at: ~U[2026-03-22 12:31:00Z]
      }

      review = Review.from_schema(schema)

      assert review.id == "review-1"
      assert review.pull_request_id == "pr-1"
      assert review.event == "request_changes"
      assert review.body == "Please add coverage"
      assert review.submitted_at == ~U[2026-03-22 12:30:00Z]
    end
  end
end
