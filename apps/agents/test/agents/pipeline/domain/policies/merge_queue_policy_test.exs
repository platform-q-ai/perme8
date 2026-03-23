defmodule Agents.Pipeline.Domain.Policies.MergeQueuePolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{PipelineRun, PullRequest, Review}
  alias Agents.Pipeline.Domain.Policies.MergeQueuePolicy

  test "marks pull requests eligible when required stages passed and review approved" do
    pull_request =
      PullRequest.new(%{
        number: 508,
        status: "approved",
        reviews: [Review.new(%{event: "approve"})]
      })

    pipeline_run =
      PipelineRun.new(%{
        stage_results: %{
          "test" => %{"stage_id" => "test", "status" => "passed"},
          "lint" => %{"stage_id" => "lint", "status" => "passed"}
        }
      })

    decision =
      MergeQueuePolicy.evaluate(pull_request, [pipeline_run], %{
        "strategy" => "merge_queue",
        "required_stages" => ["test", "lint"],
        "required_review" => true
      })

    assert decision.eligible?
    assert decision.missing_stages == []
    assert decision.review_approved?
    assert decision.reasons == []
  end

  test "returns detailed reasons when readiness requirements are missing" do
    pull_request = PullRequest.new(%{number: 509, status: "in_review", reviews: []})

    pipeline_run =
      PipelineRun.new(%{
        stage_results: %{"test" => %{"stage_id" => "test", "status" => "passed"}}
      })

    decision =
      MergeQueuePolicy.evaluate(pull_request, [pipeline_run], %{
        "strategy" => "merge_queue",
        "required_stages" => ["test", "boundary"],
        "required_review" => true
      })

    refute decision.eligible?
    assert decision.missing_stages == ["boundary"]
    assert :required_stages_not_passed in decision.reasons
    assert :approved_review_missing in decision.reasons
  end

  test "uses the latest stage result for readiness when runs disagree" do
    pull_request =
      PullRequest.new(%{
        number: 510,
        status: "approved",
        reviews: [Review.new(%{event: "approve"})]
      })

    latest_failed_run =
      PipelineRun.new(%{
        stage_results: %{"test" => %{"stage_id" => "test", "status" => "failed"}}
      })

    older_passed_run =
      PipelineRun.new(%{
        stage_results: %{"test" => %{"stage_id" => "test", "status" => "passed"}}
      })

    decision =
      MergeQueuePolicy.evaluate(pull_request, [latest_failed_run, older_passed_run], %{
        "strategy" => "merge_queue",
        "required_stages" => ["test"],
        "required_review" => true
      })

    refute decision.eligible?
    assert decision.missing_stages == ["test"]
    assert :required_stages_not_passed in decision.reasons
  end
end
