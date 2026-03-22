defmodule Agents.Pipeline.Application.UseCases.ManageMergeQueueTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.UseCases.ManageMergeQueue
  alias Agents.Pipeline.Domain.Entities.{PipelineConfig, Stage, Step}
  alias Agents.Pipeline.Infrastructure.MergeQueueWorker
  alias Agents.Pipeline.Infrastructure.Schemas.{PipelineRunSchema, PullRequestSchema}

  defmodule ParserStub do
    def parse_file(_path) do
      {:ok,
       PipelineConfig.new(%{
         version: 1,
         name: "perme8-core",
         deploy_targets: [],
         merge_queue: %{
           "strategy" => "merge_queue",
           "required_stages" => ["test"],
           "required_review" => true,
           "pre_merge_validation" => %{"strategy" => "re_run_required_stages"}
         },
         stages: [
           Stage.new(%{
             id: "warm-pool",
             type: "warm_pool",
             steps: [Step.new(%{name: "warm", run: "true"})]
           }),
           Stage.new(%{
             id: "test",
             type: "verification",
             steps: [Step.new(%{name: "unit", run: "mix test", timeout_seconds: 60})]
           })
         ]
       })}
    end
  end

  defmodule PullRequestRepoReady do
    def get_by_number(number) do
      {:ok,
       %PullRequestSchema{
         number: number,
         source_branch: "feature/merge-queue",
         target_branch: "main",
         status: "approved",
         reviews: []
       }}
    end
  end

  defmodule PullRequestRepoNotApproved do
    def get_by_number(number) do
      {:ok,
       %PullRequestSchema{
         number: number,
         source_branch: "feature/merge-queue",
         target_branch: "main",
         status: "in_review",
         reviews: []
       }}
    end
  end

  defmodule PipelineRunRepoReady do
    def list_runs_for_pull_request(number) do
      [
        %PipelineRunSchema{
          pull_request_number: number,
          stage_results: %{"test" => %{"stage_id" => "test", "status" => "passed"}}
        }
      ]
    end
  end

  defmodule StageExecutorStub do
    def execute(stage, context) do
      send(self(), {:validation_run, stage, context})
      {:ok, %{output: "validation passed", exit_code: 0, metadata: %{}}}
    end
  end

  defmodule MergePullRequestStub do
    def execute(number, _opts) do
      send(self(), {:merge_called, number})
      {:ok, %{number: number, status: "merged"}}
    end
  end

  test "merges when queue policy passes and pre-merge validation succeeds" do
    name = String.to_atom("merge_queue_worker_#{System.unique_integer([:positive])}")
    start_supervised!({MergeQueueWorker, name: name})

    assert {:ok, result} =
             ManageMergeQueue.execute(508,
               pipeline_parser: ParserStub,
               pull_request_repo: PullRequestRepoReady,
               pipeline_run_repo: PipelineRunRepoReady,
               stage_executor: StageExecutorStub,
               merge_pull_request: MergePullRequestStub,
               merge_queue_worker_name: name
             )

    assert result.status == :merged
    assert_receive {:validation_run, stage, context}
    assert stage.id == "merge-queue-validation"
    assert hd(stage.steps).run =~ "git merge --no-ff --no-commit"
    assert context["target_branch"] == "main"
    assert_receive {:merge_called, 508}
    assert MergeQueueWorker.snapshot(name: name).active == nil
  end

  test "returns not_ready when approval is missing" do
    name = String.to_atom("merge_queue_worker_#{System.unique_integer([:positive])}")
    start_supervised!({MergeQueueWorker, name: name})

    assert {:error, {:not_ready, reasons}} =
             ManageMergeQueue.execute(509,
               pipeline_parser: ParserStub,
               pull_request_repo: PullRequestRepoNotApproved,
               pipeline_run_repo: PipelineRunRepoReady,
               stage_executor: StageExecutorStub,
               merge_pull_request: MergePullRequestStub,
               merge_queue_worker_name: name
             )

    assert :approved_review_missing in reasons
  end

  test "returns queued when another pull request is already active" do
    name = String.to_atom("merge_queue_worker_#{System.unique_integer([:positive])}")
    start_supervised!({MergeQueueWorker, name: name})
    assert {:ok, _} = MergeQueueWorker.enqueue(999, name: name)
    assert {:ok, :claimed} = MergeQueueWorker.claim_next(999, name: name)

    assert {:ok, result} =
             ManageMergeQueue.execute(510,
               pipeline_parser: ParserStub,
               pull_request_repo: PullRequestRepoReady,
               pipeline_run_repo: PipelineRunRepoReady,
               stage_executor: StageExecutorStub,
               merge_pull_request: MergePullRequestStub,
               merge_queue_worker_name: name
             )

    assert result.status == :queued
    assert 510 in MergeQueueWorker.snapshot(name: name).queue
  end
end
