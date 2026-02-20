defmodule ExoDashboard.TestRuns.Domain.Policies.ResultMatcher do
  @moduledoc """
  Pure policy for matching Cucumber message IDs back to feature catalog entries.

  Maps pickle URIs and astNodeIds to features/scenarios in the parsed catalog,
  and maps test step pickleStepIds to pickle steps.
  """

  alias ExoDashboard.Features.Domain.Entities.Feature
  alias ExoDashboard.Features.Domain.Entities.Scenario

  @doc """
  Maps a Cucumber pickle (with `uri` and `astNodeIds`) back to a feature/scenario.

  Returns `%{feature_uri: uri, scenario_name: name}` on match, `nil` otherwise.
  """
  @spec match_pickle_to_feature(map(), [Feature.t()]) :: map() | nil
  def match_pickle_to_feature(%{"uri" => uri, "astNodeIds" => ast_node_ids}, features) do
    with %Feature{} = feature <- find_feature_by_uri(features, uri),
         %Scenario{} = scenario <- find_scenario_by_ids(feature.children, ast_node_ids) do
      %{feature_uri: feature.uri, scenario_name: scenario.name}
    else
      _ -> nil
    end
  end

  @doc """
  Maps a test step (via pickleStepId) back to the corresponding pickle step.

  Returns the matching pickle step map, or `nil` if not found.
  """
  @spec match_test_step_to_pickle_step(map(), [map()]) :: map() | nil
  def match_test_step_to_pickle_step(%{"pickleStepId" => pickle_step_id}, pickle_steps) do
    Enum.find(pickle_steps, fn step -> step["id"] == pickle_step_id end)
  end

  defp find_feature_by_uri(features, uri) do
    Enum.find(features, fn %Feature{uri: feature_uri} -> feature_uri == uri end)
  end

  defp find_scenario_by_ids(children, ast_node_ids) do
    Enum.find(children, fn
      %Scenario{id: id} -> id in ast_node_ids
      _ -> false
    end)
  end
end
