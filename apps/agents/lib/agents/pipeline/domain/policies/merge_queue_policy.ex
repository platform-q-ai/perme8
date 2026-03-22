defmodule Agents.Pipeline.Domain.Policies.MergeQueuePolicy do
  @moduledoc "Pure business rules for merge queue readiness and validation requirements."

  alias Agents.Pipeline.Domain.Entities.{PipelineConfig, PipelineRun, PullRequest}

  @default_config %{
    "strategy" => "disabled",
    "required_stages" => [],
    "required_review" => true,
    "pre_merge_validation" => %{"strategy" => "re_run_required_stages"}
  }

  @type decision :: %{
          eligible?: boolean(),
          strategy: String.t(),
          required_stages: [String.t()],
          passed_stages: [String.t()],
          missing_stages: [String.t()],
          required_review?: boolean(),
          review_approved?: boolean(),
          pre_merge_validation: map(),
          reasons: [atom()]
        }

  @spec from_pipeline_config(PipelineConfig.t()) :: map()
  def from_pipeline_config(%PipelineConfig{merge_queue: merge_queue}), do: normalize(merge_queue)

  @spec normalize(map() | nil) :: map()
  def normalize(nil), do: @default_config

  def normalize(raw) when is_map(raw) do
    required_stages =
      raw
      |> Map.get("required_stages", Map.get(raw, :required_stages, []))
      |> List.wrap()
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    %{
      "strategy" => Map.get(raw, "strategy", Map.get(raw, :strategy, "disabled")),
      "required_stages" => required_stages,
      "required_review" => Map.get(raw, "required_review", Map.get(raw, :required_review, true)),
      "pre_merge_validation" =>
        Map.get(
          raw,
          "pre_merge_validation",
          Map.get(raw, :pre_merge_validation, %{"strategy" => "re_run_required_stages"})
        )
    }
  end

  @spec evaluate(PullRequest.t(), [PipelineRun.t() | map()], map() | nil) :: decision()
  def evaluate(%PullRequest{} = pull_request, pipeline_runs, config \\ nil)
      when is_list(pipeline_runs) do
    policy = normalize(config)
    passed_stages = passed_stage_ids(pipeline_runs)
    missing_stages = policy["required_stages"] -- passed_stages
    review_required? = policy["required_review"]
    review_approved? = approved_review?(pull_request)

    eligible? =
      policy["strategy"] == "merge_queue" and
        missing_stages == [] and
        (not review_required? or review_approved?)

    %{
      eligible?: eligible?,
      strategy: policy["strategy"],
      required_stages: policy["required_stages"],
      passed_stages: passed_stages,
      missing_stages: missing_stages,
      required_review?: review_required?,
      review_approved?: review_approved?,
      pre_merge_validation: policy["pre_merge_validation"] || %{},
      reasons:
        build_reasons(policy["strategy"], missing_stages, review_required?, review_approved?)
    }
  end

  defp passed_stage_ids(pipeline_runs) do
    pipeline_runs
    |> Enum.flat_map(fn
      %PipelineRun{stage_results: stage_results} ->
        stage_results

      %{stage_results: stage_results} when is_map(stage_results) ->
        PipelineRun.new(%{stage_results: stage_results}).stage_results

      _ ->
        %{}
    end)
    |> Enum.filter(fn {_stage_id, result} -> Map.get(result, :status) == :passed end)
    |> Enum.map(fn {stage_id, _result} -> stage_id end)
    |> Enum.uniq()
  end

  defp approved_review?(%PullRequest{status: "approved"}), do: true

  defp approved_review?(%PullRequest{reviews: reviews}) do
    Enum.any?(reviews, &(&1.event == "approve"))
  end

  defp build_reasons("merge_queue", [], false, _review_approved), do: []
  defp build_reasons("merge_queue", [], true, true), do: []

  defp build_reasons(strategy, missing_stages, review_required?, review_approved?) do
    []
    |> maybe_add_reason(strategy != "merge_queue", :strategy_disabled)
    |> maybe_add_reason(missing_stages != [], :required_stages_not_passed)
    |> maybe_add_reason(review_required? and not review_approved?, :approved_review_missing)
  end

  defp maybe_add_reason(reasons, true, reason), do: reasons ++ [reason]
  defp maybe_add_reason(reasons, false, _reason), do: reasons
end
