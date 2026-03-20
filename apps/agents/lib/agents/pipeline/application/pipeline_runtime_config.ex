defmodule Agents.Pipeline.Application.PipelineRuntimeConfig do
  @moduledoc """
  Runtime configuration for pipeline loading dependencies.
  """

  @default_parser :"Elixir.Agents.Pipeline.Infrastructure.YamlParser"

  @doc "Returns the configured pipeline parser implementation."
  @spec pipeline_parser() :: module()
  def pipeline_parser do
    Application.get_env(:agents, :pipeline_parser, @default_parser)
  end
end
