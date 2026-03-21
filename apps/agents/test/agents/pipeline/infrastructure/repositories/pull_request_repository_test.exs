defmodule Agents.Pipeline.Infrastructure.Repositories.PullRequestRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Infrastructure.Repositories.PullRequestRepository

  describe "create_pull_request/1 and get_by_number/1" do
    test "creates persisted pull request with auto number" do
      assert {:ok, pr} =
               PullRequestRepository.create_pull_request(%{
                 source_branch: "feature/new-pr",
                 target_branch: "main",
                 title: "Introduce internal PR model",
                 body: "Body",
                 linked_ticket: 502
               })

      assert pr.number >= 1
      assert pr.status == "draft"

      assert {:ok, loaded} = PullRequestRepository.get_by_number(pr.number)
      assert loaded.source_branch == "feature/new-pr"
      assert loaded.target_branch == "main"
    end
  end

  describe "list_filtered/1" do
    test "filters by state and query" do
      {:ok, _} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/alpha",
          target_branch: "main",
          title: "Alpha work",
          status: "open"
        })

      {:ok, _} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/beta",
          target_branch: "main",
          title: "Beta work",
          status: "closed"
        })

      open_results = PullRequestRepository.list_filtered(state: "open")
      assert Enum.all?(open_results, &(&1.status == "open"))

      query_results = PullRequestRepository.list_filtered(query: "Beta")
      assert length(query_results) == 1
      assert hd(query_results).title == "Beta work"
    end
  end

  describe "add_comment/2 and add_review/2" do
    test "persists comments and reviews" do
      {:ok, pr} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/reviews",
          target_branch: "main",
          title: "Review me",
          status: "in_review"
        })

      assert {:ok, comment} =
               PullRequestRepository.add_comment(pr.number, %{
                 author_id: "u1",
                 body: "nit",
                 path: "lib/a.ex",
                 line: 9
               })

      assert comment.pull_request_id == pr.id

      assert {:ok, review} =
               PullRequestRepository.add_review(pr.number, %{
                 author_id: "u2",
                 event: "approve",
                 body: "looks good"
               })

      assert review.pull_request_id == pr.id

      assert {:ok, loaded} = PullRequestRepository.get_by_number(pr.number)
      assert length(loaded.comments) == 1
      assert length(loaded.reviews) == 1
    end
  end
end
