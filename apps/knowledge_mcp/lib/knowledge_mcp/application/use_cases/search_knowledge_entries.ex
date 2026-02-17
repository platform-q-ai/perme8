defmodule KnowledgeMcp.Application.UseCases.SearchKnowledgeEntries do
  @moduledoc """
  Searches knowledge entries by keyword, tags, and/or category.

  Lists all KnowledgeEntry entities from ERM, applies SearchPolicy for
  filtering and scoring, sorts by relevance, and returns truncated entries.
  """

  alias KnowledgeMcp.Application.GatewayConfig
  alias KnowledgeMcp.Domain.Entities.KnowledgeEntry
  alias KnowledgeMcp.Domain.Policies.SearchPolicy

  @doc """
  Searches knowledge entries.

  ## Options

    * `:erm_gateway` - Module implementing ErmGatewayBehaviour
  """
  @spec execute(String.t(), map(), keyword()) ::
          {:ok, [KnowledgeEntry.t()]} | {:error, atom()}
  def execute(workspace_id, search_params, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, GatewayConfig.erm_gateway())

    with {:ok, validated_params} <- SearchPolicy.validate_search_params(search_params),
         {:ok, entities} <- erm_gateway.list_entities(workspace_id, %{type: "KnowledgeEntry"}) do
      # NOTE: Push keyword/tag/category filtering to ERM query layer
      # when workspace knowledge bases exceed ~1000 entries. Currently
      # this is an O(n) in-memory scan over all workspace entries.
      results =
        entities
        |> Enum.map(&KnowledgeEntry.from_erm_entity/1)
        |> filter_entries(validated_params)
        |> score_and_sort(validated_params)
        |> Enum.take(validated_params.limit)
        |> Enum.map(&truncate_body/1)

      {:ok, results}
    end
  end

  defp filter_entries(entries, params) do
    entries
    |> Enum.filter(fn entry ->
      SearchPolicy.matches_tags?(entry, params.tags) and
        SearchPolicy.matches_category?(entry, params.category)
    end)
  end

  defp score_and_sort(entries, %{query: nil}), do: entries

  defp score_and_sort(entries, %{query: query}) do
    entries
    |> Enum.map(fn entry -> {entry, SearchPolicy.score_relevance(entry, query)} end)
    |> Enum.filter(fn {_entry, score} -> score > 0 end)
    |> Enum.sort_by(fn {_entry, score} -> score end, :desc)
    |> Enum.map(fn {entry, _score} -> entry end)
  end

  defp truncate_body(entry) do
    %{entry | body: KnowledgeEntry.snippet(entry)}
  end
end
