defmodule Agents.Pipeline.Infrastructure.ExoBddGitMerger do
  @moduledoc false

  @behaviour Agents.Pipeline.Application.Behaviours.GitMergerBehaviour

  @impl true
  def merge(_source_branch, _target_branch, _method, _opts \\ []), do: :ok
end
