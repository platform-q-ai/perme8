defmodule Agents.Pipeline.Application.UseCases.PullRequestWorkflowsTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Application.UseCases.CommentOnPullRequest
  alias Agents.Pipeline.Application.UseCases.ClosePullRequest
  alias Agents.Pipeline.Application.UseCases.CreatePullRequest
  alias Agents.Pipeline.Application.UseCases.GetPullRequest
  alias Agents.Pipeline.Application.UseCases.GetPullRequestDiff
  alias Agents.Pipeline.Application.UseCases.ListPullRequests
  alias Agents.Pipeline.Application.UseCases.MergePullRequest
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
