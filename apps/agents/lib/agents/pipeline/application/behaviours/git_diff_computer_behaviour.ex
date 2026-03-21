defmodule Agents.Pipeline.Application.Behaviours.GitDiffComputerBehaviour do
  @moduledoc false

  @callback compute_diff(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
end
