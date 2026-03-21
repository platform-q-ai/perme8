defmodule Agents.Pipeline.Application.PipelineRuntimeConfig do
  @moduledoc """
  Runtime configuration for pipeline loading dependencies.
  """

  @default_parser :"Elixir.Agents.Pipeline.Infrastructure.YamlParser"
  @default_pull_request_repository :"Elixir.Agents.Pipeline.Infrastructure.Repositories.PullRequestRepository"
  @default_pipeline_run_repository :"Elixir.Agents.Pipeline.Infrastructure.Repositories.PipelineRunRepository"
  @default_git_diff_computer :"Elixir.Agents.Pipeline.Infrastructure.GitDiffComputer"
  @default_git_merger :"Elixir.Agents.Pipeline.Infrastructure.GitMerger"
  @default_stage_executor :"Elixir.Agents.Pipeline.Infrastructure.StageExecutor"
  @default_session_reopener :"Elixir.Agents.Pipeline.Infrastructure.SessionReopener"
  @default_event_bus Perme8.Events.EventBus

  @doc "Returns the configured pipeline parser implementation."
  @spec pipeline_parser() :: module()
  def pipeline_parser do
    Application.get_env(:agents, :pipeline_parser, @default_parser)
  end

  @doc "Returns the configured internal pull request repository implementation."
  @spec pull_request_repository() :: module()
  def pull_request_repository do
    Application.get_env(:agents, :pull_request_repository, @default_pull_request_repository)
  end

  @doc "Returns the configured pipeline run repository implementation."
  @spec pipeline_run_repository() :: module()
  def pipeline_run_repository do
    Application.get_env(:agents, :pipeline_run_repository, @default_pipeline_run_repository)
  end

  @doc "Returns the configured pull request diff computer implementation."
  @spec git_diff_computer() :: module()
  def git_diff_computer do
    Application.get_env(:agents, :pr_diff_computer, @default_git_diff_computer)
  end

  @doc "Returns the configured pull request git merger implementation."
  @spec git_merger() :: module()
  def git_merger do
    Application.get_env(:agents, :pr_git_merger, @default_git_merger)
  end

  @doc "Returns the configured stage executor implementation."
  @spec stage_executor() :: module()
  def stage_executor do
    Application.get_env(:agents, :pipeline_stage_executor, @default_stage_executor)
  end

  @doc "Returns the configured session reopener implementation."
  @spec session_reopener() :: module()
  def session_reopener do
    Application.get_env(:agents, :pipeline_session_reopener, @default_session_reopener)
  end

  @doc "Returns the configured event bus implementation."
  @spec event_bus() :: module()
  def event_bus do
    Application.get_env(:agents, :pipeline_event_bus, @default_event_bus)
  end
end
