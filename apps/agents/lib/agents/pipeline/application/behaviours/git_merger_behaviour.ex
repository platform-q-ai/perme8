defmodule Agents.Pipeline.Application.Behaviours.GitMergerBehaviour do
  @moduledoc false

  @callback merge(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
end
