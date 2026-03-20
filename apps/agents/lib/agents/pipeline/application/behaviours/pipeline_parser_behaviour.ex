defmodule Agents.Pipeline.Application.Behaviours.PipelineParserBehaviour do
  @moduledoc """
  Behaviour for loading and validating pipeline configuration files.
  """

  alias Agents.Pipeline.Domain.Entities.PipelineConfig

  @doc "Parses a pipeline file and returns a validated pipeline config."
  @callback parse_file(Path.t()) :: {:ok, PipelineConfig.t()} | {:error, [String.t()]}
end
