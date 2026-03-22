defmodule Agents.Pipeline do
  @moduledoc "Public facade for pipeline and internal pull request operations."

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain, Agents.Pipeline.Application, Agents.Pipeline.Infrastructure],
    exports: [
      {Domain.Entities.PipelineRun, []},
      {Domain.Entities.PullRequest, []},
      {Domain.Entities.Review, []},
      {Domain.Entities.ReviewComment, []}
    ]

  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.Application.UseCases.CommentOnPullRequest
  alias Agents.Pipeline.Application.UseCases.ClosePullRequest
  alias Agents.Pipeline.Application.UseCases.CreatePullRequest
  alias Agents.Pipeline.Application.UseCases.GetPipelineKanban
  alias Agents.Pipeline.Application.UseCases.GetPipelineStatus
  alias Agents.Pipeline.Application.UseCases.GetPullRequest
  alias Agents.Pipeline.Application.UseCases.GetPullRequestDiff
  alias Agents.Pipeline.Application.UseCases.ListPullRequests
  alias Agents.Pipeline.Application.UseCases.MergePullRequest
  alias Agents.Pipeline.Application.UseCases.ReplenishWarmPool
  alias Agents.Pipeline.Application.UseCases.RunStage
  alias Agents.Pipeline.Application.UseCases.ReviewPullRequest
  alias Agents.Pipeline.Application.UseCases.TriggerPipelineRun
  alias Agents.Pipeline.Application.UseCases.UpdatePullRequest

  @spec load_pipeline(Path.t(), keyword()) ::
          {:ok, Agents.Pipeline.Domain.Entities.PipelineConfig.t()} | {:error, [String.t()]}
  defdelegate load_pipeline(path \\ "perme8-pipeline.yml", opts \\ []),
    to: LoadPipeline,
    as: :execute

  @spec create_pull_request(map(), keyword()) ::
          {:ok, Domain.Entities.PullRequest.t()} | {:error, term()}
  defdelegate create_pull_request(attrs, opts \\ []), to: CreatePullRequest, as: :execute

  @spec trigger_pipeline_run(map(), keyword()) ::
          {:ok, Domain.Entities.PipelineRun.t()} | {:ok, nil} | {:error, term()}
  defdelegate trigger_pipeline_run(attrs, opts \\ []), to: TriggerPipelineRun, as: :execute

  @spec run_stage(Ecto.UUID.t(), keyword()) ::
          {:ok, Domain.Entities.PipelineRun.t()} | {:error, term()}
  defdelegate run_stage(run_id, opts \\ []), to: RunStage, as: :execute

  @doc "Runs a warm-pool replenishment cycle using the configured pipeline stage."
  @spec replenish_warm_pool(keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate replenish_warm_pool(opts \\ []), to: ReplenishWarmPool, as: :execute

  @spec get_pipeline_status(Ecto.UUID.t(), keyword()) ::
          {:ok, Domain.Entities.PipelineRun.t()} | {:error, term()}
  defdelegate get_pipeline_status(run_id, opts \\ []), to: GetPipelineStatus, as: :execute

  @spec get_pipeline_kanban([map()], keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate get_pipeline_kanban(tickets, opts \\ []), to: GetPipelineKanban, as: :execute

  @spec get_pull_request(integer(), keyword()) ::
          {:ok, Domain.Entities.PullRequest.t()} | {:error, :not_found}
  defdelegate get_pull_request(number, opts \\ []), to: GetPullRequest, as: :execute

  @spec list_pull_requests(keyword(), keyword()) :: {:ok, [Domain.Entities.PullRequest.t()]}
  defdelegate list_pull_requests(filters \\ [], opts \\ []), to: ListPullRequests, as: :execute

  @spec update_pull_request(integer(), map(), keyword()) ::
          {:ok, Domain.Entities.PullRequest.t()} | {:error, term()}
  defdelegate update_pull_request(number, attrs, opts \\ []),
    to: UpdatePullRequest,
    as: :execute

  @spec comment_on_pull_request(integer(), map(), keyword()) ::
          {:ok, Domain.Entities.PullRequest.t()} | {:error, term()}
  defdelegate comment_on_pull_request(number, attrs, opts \\ []),
    to: CommentOnPullRequest,
    as: :execute

  @spec review_pull_request(integer(), map(), keyword()) ::
          {:ok, Domain.Entities.PullRequest.t()} | {:error, term()}
  defdelegate review_pull_request(number, attrs, opts \\ []),
    to: ReviewPullRequest,
    as: :execute

  @spec merge_pull_request(integer(), keyword()) ::
          {:ok, Domain.Entities.PullRequest.t()} | {:error, term()}
  defdelegate merge_pull_request(number, opts \\ []), to: MergePullRequest, as: :execute

  @spec close_pull_request(integer(), keyword()) ::
          {:ok, Domain.Entities.PullRequest.t()} | {:error, term()}
  defdelegate close_pull_request(number, opts \\ []), to: ClosePullRequest, as: :execute

  @spec get_pull_request_diff(integer(), keyword()) ::
          {:ok, %{pull_request: Domain.Entities.PullRequest.t(), diff: String.t()}}
          | {:error, term()}
  defdelegate get_pull_request_diff(number, opts \\ []), to: GetPullRequestDiff, as: :execute
end
