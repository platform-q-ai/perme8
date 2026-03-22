defmodule Agents.Pipeline.Application.UseCases.PullRequestWorkflowsTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Application.UseCases.CommentOnPullRequest
  alias Agents.Pipeline.Application.UseCases.ClosePullRequest
  alias Agents.Pipeline.Application.UseCases.CreatePullRequest
  alias Agents.Pipeline.Application.UseCases.GetPullRequest
  alias Agents.Pipeline.Application.UseCases.GetPullRequestByLinkedTicket
  alias Agents.Pipeline.Application.UseCases.GetPullRequestDiff
  alias Agents.Pipeline.Application.UseCases.ListPullRequests
  alias Agents.Pipeline.Application.UseCases.MergePullRequest
  alias Agents.Pipeline.Application.UseCases.ReplyToPullRequestComment
  alias Agents.Pipeline.Application.UseCases.ResolvePullRequestThread
  alias Agents.Pipeline.Application.UseCases.ReviewPullRequest
  alias Agents.Pipeline.Application.UseCases.UpdatePullRequest

  defmodule DiffComputerStub do
    def compute_diff(source_branch, target_branch) do
      Process.get({__MODULE__, :compute_diff}).(source_branch, target_branch)
    end
  end

  defmodule GitMergerStub do
    def merge(source_branch, target_branch, method) do
      Process.get({__MODULE__, :merge}).(source_branch, target_branch, method)
    end
  end

  describe "PR workflow use cases" do
    test "create + read + list" do
      assert {:ok, pr} =
               CreatePullRequest.execute(%{
                 source_branch: "feature/one",
                 target_branch: "main",
                 title: "Internal PR"
               })

      assert pr.number >= 1

      assert {:ok, loaded} = GetPullRequest.execute(pr.number)
      assert loaded.title == "Internal PR"

      assert {:ok, prs} = ListPullRequests.execute(state: "draft")
      assert Enum.any?(prs, &(&1.number == pr.number))
    end

    test "gets pull request by linked ticket" do
      assert {:ok, created} =
               CreatePullRequest.execute(%{
                 source_branch: "feature/ticket-lookup",
                 target_branch: "main",
                 title: "Lookup linked ticket",
                 linked_ticket: 506
               })

      assert {:ok, loaded} = GetPullRequestByLinkedTicket.execute(506)
      assert loaded.number == created.number
      assert loaded.linked_ticket == 506
    end

    test "update transitions state using policy" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/two",
          target_branch: "main",
          title: "To review",
          status: "open"
        })

      assert {:ok, updated} = UpdatePullRequest.execute(pr.number, %{status: "in_review"})
      assert updated.status == "in_review"

      assert {:error, :invalid_transition} =
               UpdatePullRequest.execute(pr.number, %{status: "draft"})
    end

    test "comment and review on pull request" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/comments",
          target_branch: "main",
          title: "Review this",
          status: "in_review"
        })

      assert {:ok, _comment} =
               CommentOnPullRequest.execute(pr.number, %{
                 actor_id: "reviewer-1",
                 body: "Please rename variable",
                 path: "lib/x.ex",
                 line: 21
               })

      assert {:ok, reviewed} =
               ReviewPullRequest.execute(pr.number, %{
                 actor_id: "reviewer-2",
                 event: "approve",
                 body: "Looks good"
               })

      assert reviewed.status == "approved"
      assert length(reviewed.comments) == 1
      assert length(reviewed.reviews) == 1
    end

    test "replies to an existing review comment thread" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/reply-thread",
          target_branch: "main",
          title: "Reply flow",
          status: "in_review"
        })

      {:ok, with_comment} =
        CommentOnPullRequest.execute(pr.number, %{
          actor_id: "reviewer-1",
          body: "Can we simplify this?",
          path: "lib/reply_flow.ex",
          line: 7
        })

      root_comment = hd(with_comment.comments)

      assert {:ok, updated} =
               ReplyToPullRequestComment.execute(pr.number, root_comment.id, %{
                 actor_id: "author-1",
                 body: "Yes, I will split it out."
               })

      reply = Enum.find(updated.comments, &(&1.parent_comment_id == root_comment.id))
      assert reply
      assert reply.body == "Yes, I will split it out."
      assert reply.author_id == "author-1"
    end

    test "resolves a review thread" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/resolve-thread",
          target_branch: "main",
          title: "Resolve flow",
          status: "in_review"
        })

      {:ok, with_comment} =
        CommentOnPullRequest.execute(pr.number, %{
          actor_id: "reviewer-1",
          body: "Please add tests",
          path: "test/sample_test.exs",
          line: 11
        })

      root_comment = hd(with_comment.comments)

      assert {:ok, updated} =
               ResolvePullRequestThread.execute(pr.number, root_comment.id, %{
                 actor_id: "maintainer-1"
               })

      resolved = Enum.find(updated.comments, &(&1.id == root_comment.id))
      assert resolved.resolved
      assert resolved.resolved_by == "maintainer-1"
      assert resolved.resolved_at
    end

    test "rejects replies when parent comment belongs to another pull request" do
      {:ok, pr_one} =
        CreatePullRequest.execute(%{
          source_branch: "feature/pr-one",
          target_branch: "main",
          title: "PR one",
          status: "in_review"
        })

      {:ok, pr_two} =
        CreatePullRequest.execute(%{
          source_branch: "feature/pr-two",
          target_branch: "main",
          title: "PR two",
          status: "in_review"
        })

      {:ok, with_comment} =
        CommentOnPullRequest.execute(pr_one.number, %{
          actor_id: "reviewer-1",
          body: "Wrong PR",
          path: "lib/reply_flow.ex",
          line: 3
        })

      root_comment = hd(with_comment.comments)

      assert {:error, :not_found} =
               ReplyToPullRequestComment.execute(pr_two.number, root_comment.id, %{
                 actor_id: "author-1",
                 body: "This should fail"
               })
    end

    test "rejects resolving a thread from another pull request" do
      {:ok, pr_one} =
        CreatePullRequest.execute(%{
          source_branch: "feature/pr-one",
          target_branch: "main",
          title: "PR one",
          status: "in_review"
        })

      {:ok, pr_two} =
        CreatePullRequest.execute(%{
          source_branch: "feature/pr-two",
          target_branch: "main",
          title: "PR two",
          status: "in_review"
        })

      {:ok, with_comment} =
        CommentOnPullRequest.execute(pr_one.number, %{
          actor_id: "reviewer-1",
          body: "Wrong PR",
          path: "lib/reply_flow.ex",
          line: 3
        })

      root_comment = hd(with_comment.comments)

      assert {:error, :not_found} =
               ResolvePullRequestThread.execute(pr_two.number, root_comment.id, %{
                 actor_id: "maintainer-1"
               })
    end

    test "review enforces transition policy" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/review-policy",
          target_branch: "main",
          title: "Review policy",
          status: "open"
        })

      assert {:error, :invalid_transition} =
               ReviewPullRequest.execute(pr.number, %{
                 actor_id: "reviewer-2",
                 event: "approve",
                 body: "Looks good"
               })
    end

    test "gets PR diff using injected diff computer" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/diff",
          target_branch: "main",
          title: "Diff me"
        })

      Process.put({DiffComputerStub, :compute_diff}, fn "feature/diff", "main" ->
        {:ok, "diff --git a/file b/file\n+new"}
      end)

      assert {:ok, %{pull_request: loaded, diff: diff}} =
               GetPullRequestDiff.execute(pr.number, diff_computer: DiffComputerStub)

      assert loaded.number == pr.number
      assert diff =~ "diff --git"
    end

    test "returns error when diff computer fails" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/diff-fail",
          target_branch: "main",
          title: "Diff fail"
        })

      Process.put({DiffComputerStub, :compute_diff}, fn _source, _target ->
        {:error, {:git_diff_failed, "bad revision"}}
      end)

      assert {:error, {:git_diff_failed, "bad revision"}} =
               GetPullRequestDiff.execute(pr.number, diff_computer: DiffComputerStub)
    end

    test "merges approved PR through injected git merger" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/merge",
          target_branch: "main",
          title: "Merge me",
          status: "approved"
        })

      Process.put({GitMergerStub, :merge}, fn "feature/merge", "main", "merge" -> :ok end)

      assert {:ok, merged} =
               MergePullRequest.execute(pr.number,
                 merge_method: "merge",
                 git_merger: GitMergerStub
               )

      assert merged.status == "merged"
      assert merged.merged_at != nil
    end

    test "returns not_mergeable for unapproved pull request" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/not-mergeable",
          target_branch: "main",
          title: "Not mergeable",
          status: "open"
        })

      assert {:error, :not_mergeable} =
               MergePullRequest.execute(pr.number, git_merger: GitMergerStub)
    end

    test "propagates merge adapter failures" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/merge-fail",
          target_branch: "main",
          title: "Merge fail",
          status: "approved"
        })

      Process.put({GitMergerStub, :merge}, fn _source, _target, _method ->
        {:error, {:git_merge_failed, "conflict"}}
      end)

      assert {:error, {:git_merge_failed, "conflict"}} =
               MergePullRequest.execute(pr.number, git_merger: GitMergerStub)
    end

    test "closes pull request" do
      {:ok, pr} =
        CreatePullRequest.execute(%{
          source_branch: "feature/close",
          target_branch: "main",
          title: "Close me",
          status: "open"
        })

      assert {:ok, closed} = ClosePullRequest.execute(pr.number)
      assert closed.status == "closed"
      assert closed.closed_at != nil
    end

    test "returns not_found when closing missing pull request" do
      assert {:error, :not_found} = ClosePullRequest.execute(999_999)
    end
  end
end
