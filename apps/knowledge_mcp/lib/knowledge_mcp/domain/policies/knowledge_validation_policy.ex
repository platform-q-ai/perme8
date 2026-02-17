defmodule KnowledgeMcp.Domain.Policies.KnowledgeValidationPolicy do
  @moduledoc """
  Pure business rules for validating knowledge entry attributes and relationship types.

  All functions are pure — no I/O, no database access, no side effects.
  """

  @categories ~w(how_to pattern convention architecture_decision gotcha concept)
  @relationship_types ~w(relates_to depends_on prerequisite_for example_of part_of supersedes)
  @max_title_length 255
  @max_tags 20

  @doc "Returns the list of all valid categories."
  @spec categories() :: [String.t()]
  def categories, do: @categories

  @doc "Returns the list of all valid relationship types."
  @spec relationship_types() :: [String.t()]
  def relationship_types, do: @relationship_types

  @doc "Returns true if the given string is a valid category."
  @spec valid_category?(term()) :: boolean()
  def valid_category?(category) when is_binary(category), do: category in @categories
  def valid_category?(_), do: false

  @doc "Returns true if the given string is a valid relationship type."
  @spec valid_relationship_type?(term()) :: boolean()
  def valid_relationship_type?(type) when is_binary(type), do: type in @relationship_types
  def valid_relationship_type?(_), do: false

  @doc """
  Validates entry creation attributes.

  Requires title (non-empty, <= 255 chars), body (non-empty), and valid category.
  """
  @spec validate_entry_attrs(map()) :: :ok | {:error, atom()}
  def validate_entry_attrs(attrs) do
    with :ok <- validate_title_present(attrs),
         :ok <- validate_title_length(attrs),
         :ok <- validate_body_present(attrs) do
      validate_category(attrs)
    end
  end

  @doc """
  Validates entry update attributes (partial updates).

  No required fields — only validates fields that are present.
  """
  @spec validate_update_attrs(map()) :: :ok | {:error, atom()}
  def validate_update_attrs(attrs) do
    with :ok <- validate_optional_title_length(attrs) do
      validate_optional_category(attrs)
    end
  end

  @doc """
  Validates a list of tags.

  Tags must be non-empty strings, max 20 tags.
  """
  @spec validate_tags([term()]) :: :ok | {:error, atom()}
  def validate_tags(tags) when is_list(tags) do
    cond do
      length(tags) > @max_tags -> {:error, :too_many_tags}
      Enum.any?(tags, &(!is_binary(&1) || &1 == "")) -> {:error, :invalid_tag}
      true -> :ok
    end
  end

  @doc """
  Validates that a relationship is not a self-reference.
  """
  @spec validate_self_reference(String.t(), String.t()) :: :ok | {:error, :self_reference}
  def validate_self_reference(from_id, to_id) when from_id == to_id, do: {:error, :self_reference}
  def validate_self_reference(_from_id, _to_id), do: :ok

  # Private helpers

  defp validate_title_present(%{title: title}) when is_binary(title) and title != "", do: :ok
  defp validate_title_present(%{title: _}), do: {:error, :title_required}
  defp validate_title_present(_), do: {:error, :title_required}

  defp validate_title_length(%{title: title}) when is_binary(title) do
    if String.length(title) > @max_title_length, do: {:error, :title_too_long}, else: :ok
  end

  defp validate_title_length(_), do: :ok

  defp validate_body_present(%{body: body}) when is_binary(body) and body != "", do: :ok
  defp validate_body_present(%{body: _}), do: {:error, :body_required}
  defp validate_body_present(_), do: {:error, :body_required}

  defp validate_category(%{category: category}) when is_binary(category) do
    if valid_category?(category), do: :ok, else: {:error, :invalid_category}
  end

  defp validate_category(_), do: {:error, :invalid_category}

  defp validate_optional_title_length(%{title: title}) when is_binary(title) do
    if String.length(title) > @max_title_length, do: {:error, :title_too_long}, else: :ok
  end

  defp validate_optional_title_length(_), do: :ok

  defp validate_optional_category(%{category: category}) when is_binary(category) do
    if valid_category?(category), do: :ok, else: {:error, :invalid_category}
  end

  defp validate_optional_category(_), do: :ok
end
