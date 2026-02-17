defmodule Agents.Domain.Entities.KnowledgeEntry do
  @moduledoc """
  Pure domain entity representing a knowledge entry.

  Wraps ERM Entity properties with typed fields for the knowledge domain.
  This is a pure struct with no I/O dependencies.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t() | nil,
          title: String.t() | nil,
          body: String.t() | nil,
          category: String.t() | nil,
          tags: [String.t()],
          code_snippets: [map()],
          file_paths: [String.t()],
          external_links: [map()],
          last_verified_at: String.t() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :workspace_id,
    :title,
    :body,
    :category,
    :last_verified_at,
    :created_at,
    :updated_at,
    tags: [],
    code_snippets: [],
    file_paths: [],
    external_links: []
  ]

  @doc """
  Creates a new KnowledgeEntry from an atom-keyed map.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an ERM Entity with properties into a KnowledgeEntry.

  Decodes JSON-encoded list fields from ERM properties.
  """
  @spec from_erm_entity(map()) :: t()
  def from_erm_entity(%{properties: properties} = entity) do
    %__MODULE__{
      id: entity.id,
      workspace_id: entity.workspace_id,
      title: Map.get(properties, "title"),
      body: Map.get(properties, "body"),
      category: Map.get(properties, "category"),
      tags: decode_json_list(Map.get(properties, "tags")),
      code_snippets: decode_json_list(Map.get(properties, "code_snippets")),
      file_paths: decode_json_list(Map.get(properties, "file_paths")),
      external_links: decode_json_list(Map.get(properties, "external_links")),
      last_verified_at: Map.get(properties, "last_verified_at"),
      created_at: entity.created_at,
      updated_at: entity.updated_at
    }
  end

  @doc """
  Converts a KnowledgeEntry to ERM-compatible properties map.

  JSON-encodes list fields for storage in ERM properties.
  """
  @spec to_erm_properties(t()) :: map()
  def to_erm_properties(%__MODULE__{} = entry) do
    %{
      "title" => entry.title,
      "body" => entry.body,
      "category" => entry.category,
      "tags" => Jason.encode!(entry.tags || []),
      "code_snippets" => Jason.encode!(entry.code_snippets || []),
      "file_paths" => Jason.encode!(entry.file_paths || []),
      "external_links" => Jason.encode!(entry.external_links || []),
      "last_verified_at" => entry.last_verified_at
    }
  end

  @doc """
  Returns a snippet of the entry body for search result previews.

  Truncates to 200 characters with "..." suffix if longer.
  """
  @spec snippet(t()) :: String.t()
  def snippet(%__MODULE__{body: nil}), do: ""

  def snippet(%__MODULE__{body: body}) when is_binary(body) do
    if String.length(body) <= 200, do: body, else: String.slice(body, 0, 200) <> "..."
  end

  defp decode_json_list(nil), do: []
  defp decode_json_list(""), do: []

  defp decode_json_list(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  defp decode_json_list(other) when is_list(other), do: other
  defp decode_json_list(_), do: []
end
