defmodule Agents.Domain.Policies.SearchPolicy do
  @moduledoc """
  Pure business rules for search parameter validation and relevance ranking.

  All functions are pure — no I/O, no database access, no side effects.
  """

  alias Agents.Domain.Entities.KnowledgeEntry
  alias Agents.Domain.Policies.KnowledgeValidationPolicy

  @default_limit 20
  @min_limit 1
  @max_limit 100
  @default_depth 2
  @min_depth 1
  @max_depth 5
  @title_match_weight 10
  @body_match_weight 3

  @doc """
  Validates search parameters.

  At least one of query, tags (non-empty), or category must be present.
  Clamps limit to 1..100 (default 20). Validates category if present.
  Returns `{:ok, normalized_params}` or `{:error, reason}`.
  """
  @spec validate_search_params(map()) :: {:ok, map()} | {:error, atom()}
  def validate_search_params(params) do
    parsed = parse_search_fields(params)

    with :ok <- validate_category_if_present(parsed),
         :ok <- validate_has_criteria(parsed) do
      {:ok, normalize_search_params(parsed)}
    end
  end

  defp parse_search_fields(params) do
    query = Map.get(params, :query)
    tags = Map.get(params, :tags)
    category = Map.get(params, :category)
    limit = Map.get(params, :limit)

    %{
      query: query,
      tags: tags,
      category: category,
      limit: limit,
      has_query: is_binary(query) and query != "",
      has_tags: is_list(tags) and tags != [],
      has_category: is_binary(category) and category != ""
    }
  end

  defp validate_category_if_present(%{has_category: true, category: category}) do
    if KnowledgeValidationPolicy.valid_category?(category),
      do: :ok,
      else: {:error, :invalid_category}
  end

  defp validate_category_if_present(_), do: :ok

  defp validate_has_criteria(%{has_query: false, has_tags: false, has_category: false}) do
    {:error, :empty_search}
  end

  defp validate_has_criteria(_), do: :ok

  defp normalize_search_params(
         %{has_query: has_query, has_tags: has_tags, has_category: has_category} = parsed
       ) do
    %{
      query: if(has_query, do: parsed.query, else: nil),
      tags: if(has_tags, do: parsed.tags, else: []),
      category: if(has_category, do: parsed.category, else: nil),
      limit: clamp_limit(parsed.limit)
    }
  end

  @doc """
  Scores relevance of a knowledge entry against a search query.

  Title matches score higher than body matches. Returns 0 for no match.
  Case-insensitive.
  """
  @spec score_relevance(KnowledgeEntry.t(), String.t()) :: non_neg_integer()
  def score_relevance(%KnowledgeEntry{} = entry, query) when is_binary(query) do
    query_lower = String.downcase(query)
    title_lower = String.downcase(entry.title || "")
    body_lower = String.downcase(entry.body || "")

    title_score = if String.contains?(title_lower, query_lower), do: @title_match_weight, else: 0
    body_score = if String.contains?(body_lower, query_lower), do: @body_match_weight, else: 0

    title_score + body_score
  end

  @doc """
  Returns true when the entry has ALL specified filter tags (AND logic).

  Returns true when filter tags is nil or empty.
  """
  @spec matches_tags?(KnowledgeEntry.t(), [String.t()] | nil) :: boolean()
  def matches_tags?(_entry, nil), do: true
  def matches_tags?(_entry, []), do: true

  def matches_tags?(%KnowledgeEntry{tags: entry_tags}, filter_tags) when is_list(filter_tags) do
    Enum.all?(filter_tags, &(&1 in entry_tags))
  end

  @doc """
  Returns true when the entry matches the category filter.

  Returns true when no category filter (nil).
  """
  @spec matches_category?(KnowledgeEntry.t(), String.t() | nil) :: boolean()
  def matches_category?(_entry, nil), do: true

  def matches_category?(%KnowledgeEntry{category: entry_category}, filter_category) do
    entry_category == filter_category
  end

  @doc """
  Clamps traversal depth to 1..5 range (default 2).
  """
  @spec clamp_depth(integer() | nil) :: pos_integer()
  def clamp_depth(nil), do: @default_depth
  def clamp_depth(depth) when is_integer(depth), do: max(@min_depth, min(@max_depth, depth))

  # Private

  defp clamp_limit(nil), do: @default_limit
  defp clamp_limit(limit) when is_integer(limit), do: max(@min_limit, min(@max_limit, limit))
  defp clamp_limit(_), do: @default_limit
end
