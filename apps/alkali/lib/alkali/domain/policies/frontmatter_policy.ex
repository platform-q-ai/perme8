defmodule Alkali.Domain.Policies.FrontmatterPolicy do
  @moduledoc """
  FrontmatterPolicy defines business rules for validating frontmatter.

  Pure function with no I/O or side effects.
  """

  @doc """
  Validates frontmatter fields.

  Required fields:
  - title: must be present and non-empty

  Optional fields with type validation:
  - date: must be valid ISO 8601 format if present
  - tags: must be a list if present
  - draft: must be boolean if present

  Returns {:ok, frontmatter} if valid, {:error, reasons} otherwise.

  ## Examples

      iex> FrontmatterPolicy.validate_frontmatter(%{"title" => "My Post"})
      {:ok, %{"title" => "My Post"}}

      iex> FrontmatterPolicy.validate_frontmatter(%{})
      {:error, ["title is required"]}

      iex> FrontmatterPolicy.validate_frontmatter(%{"title" => "Post", "tags" => "not-list"})
      {:error, ["tags must be a list"]}
  """
  @spec validate_frontmatter(map()) :: {:ok, map()} | {:error, list(String.t())}
  def validate_frontmatter(frontmatter) do
    errors =
      []
      |> validate_title(frontmatter)
      |> validate_date(frontmatter)
      |> validate_tags(frontmatter)
      |> validate_draft(frontmatter)

    case errors do
      [] -> {:ok, frontmatter}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  # Private Validation Functions

  defp validate_title(errors, frontmatter) do
    case Map.get(frontmatter, "title") do
      nil ->
        ["Missing required field 'title'" | errors]

      "" ->
        ["title cannot be empty" | errors]

      _title ->
        errors
    end
  end

  defp validate_date(errors, frontmatter) do
    case Map.get(frontmatter, "date") do
      nil ->
        errors

      date when is_binary(date) ->
        # Try parsing as Date first (YYYY-MM-DD), then as DateTime (full ISO 8601)
        cond do
          match?({:ok, _}, Date.from_iso8601(date)) ->
            errors

          match?({:ok, _, _}, DateTime.from_iso8601(date)) ->
            errors

          true ->
            error_msg =
              ~s<Invalid date format, expected ISO 8601 (e.g., "2024-01-15" or "2024-01-15T10:30:00Z"), got: "#{date}">

            [error_msg | errors]
        end

      _other ->
        ["Invalid date format, expected ISO 8601 string" | errors]
    end
  end

  defp validate_tags(errors, frontmatter) do
    case Map.get(frontmatter, "tags") do
      nil ->
        errors

      tags when is_list(tags) ->
        errors

      _other ->
        ["Tags must be a list of strings" | errors]
    end
  end

  defp validate_draft(errors, frontmatter) do
    case Map.get(frontmatter, "draft") do
      nil ->
        errors

      draft when is_boolean(draft) ->
        errors

      _other ->
        ["draft must be a boolean" | errors]
    end
  end
end
