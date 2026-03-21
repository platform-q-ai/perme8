defmodule Agents.Pipeline.Infrastructure.ExoBddGitDiffComputer do
  @moduledoc false

  @behaviour Agents.Pipeline.Application.Behaviours.GitDiffComputerBehaviour

  @impl true
  def compute_diff(source_branch, target_branch) do
    {:ok,
     "diff --git a/#{target_branch}.txt b/#{source_branch}.txt\n--- a/#{target_branch}.txt\n+++ b/#{source_branch}.txt\n@@ -1 +1 @@\n-legacy\n+updated\n"}
  end
end
