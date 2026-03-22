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

    test "gets pull request by linked ticket" do
      {:ok, created} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/ticket-lookup",
          target_branch: "main",
          title: "Lookup by ticket",
          linked_ticket: 506
        })

      assert {:ok, loaded} = PullRequestRepository.get_by_linked_ticket(506)
      assert loaded.id == created.id
      assert loaded.number == created.number
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

    test "persists reply threading metadata and supports resolving threads" do
      {:ok, pr} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/threads",
          target_branch: "main",
          title: "Thread me",
          status: "in_review"
        })

      assert {:ok, root_comment} =
               PullRequestRepository.add_comment(pr.number, %{
                 author_id: "u1",
                 body: "Please refactor this function",
                 path: "lib/app.ex",
                 line: 12
               })

      assert {:ok, reply_comment} =
               PullRequestRepository.add_comment(pr.number, %{
                 author_id: "u2",
                 body: "Thanks, updating now",
                 parent_comment_id: root_comment.id
               })

      assert reply_comment.parent_comment_id == root_comment.id
      refute reply_comment.resolved
      assert is_nil(reply_comment.resolved_at)
      assert is_nil(reply_comment.resolved_by)

      assert {:ok, resolved_comment} =
               PullRequestRepository.resolve_comment_thread(pr.number, root_comment.id, "u3")

      assert resolved_comment.resolved
      assert resolved_comment.resolved_by == "u3"
      assert resolved_comment.resolved_at

      assert {:ok, loaded} = PullRequestRepository.get_by_number(pr.number)

      reloaded_root = Enum.find(loaded.comments, &(&1.id == root_comment.id))
      reloaded_reply = Enum.find(loaded.comments, &(&1.id == reply_comment.id))

      assert reloaded_root.resolved
      assert reloaded_root.resolved_by == "u3"
      assert reloaded_reply.parent_comment_id == root_comment.id
    end

    test "preserves legacy flat comment creation behavior" do
      {:ok, pr} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/flat-comments",
          target_branch: "main",
          title: "Flat comments remain",
          status: "open"
        })

      assert {:ok, comment} =
               PullRequestRepository.add_comment(pr.number, %{
                 author_id: "u-flat",
                 body: "Legacy comment body"
               })

      assert is_nil(comment.parent_comment_id)
      refute comment.resolved
      assert is_nil(comment.resolved_at)
      assert is_nil(comment.resolved_by)
    end

    test "rejects replies that target a comment from another pull request" do
      {:ok, pr_one} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/one",
          target_branch: "main",
          title: "PR one",
          status: "in_review"
        })

      {:ok, pr_two} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/two",
          target_branch: "main",
          title: "PR two",
          status: "in_review"
        })

      {:ok, root_comment} =
        PullRequestRepository.add_comment(pr_one.number, %{
          author_id: "u1",
          body: "Root"
        })

      assert {:error, :not_found} =
               PullRequestRepository.add_comment(pr_two.number, %{
                 author_id: "u2",
                 body: "Cross PR reply",
                 parent_comment_id: root_comment.id
               })
    end

    test "rejects resolving a comment from another pull request" do
      {:ok, pr_one} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/one",
          target_branch: "main",
          title: "PR one",
          status: "in_review"
        })

      {:ok, pr_two} =
        PullRequestRepository.create_pull_request(%{
          source_branch: "feature/two",
          target_branch: "main",
          title: "PR two",
          status: "in_review"
        })

      {:ok, root_comment} =
        PullRequestRepository.add_comment(pr_one.number, %{
          author_id: "u1",
          body: "Root"
        })

      assert {:error, :not_found} =
               PullRequestRepository.resolve_comment_thread(pr_two.number, root_comment.id, "u2")
    end
  end
end
