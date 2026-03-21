defmodule Agents.Pipeline.Domain.Entities.ReviewEntitiesTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{Review, ReviewComment}

  test "review new/1 sets fields" do
    review = Review.new(%{author_id: "u1", event: "approve", body: "ok"})

    assert review.author_id == "u1"
    assert review.event == "approve"
    assert review.body == "ok"
  end

  test "review_comment new/1 sets fields" do
    comment =
      ReviewComment.new(%{author_id: "u2", body: "nit", path: "lib/x.ex", line: 3})

    assert comment.author_id == "u2"
    assert comment.body == "nit"
    assert comment.path == "lib/x.ex"
    assert comment.line == 3
  end
end
