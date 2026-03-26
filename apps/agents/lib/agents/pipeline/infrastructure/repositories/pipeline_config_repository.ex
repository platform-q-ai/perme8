defmodule Agents.Pipeline.Infrastructure.Repositories.PipelineConfigRepository do
  @moduledoc "Persistence operations for the current pipeline configuration."

  alias Agents.Pipeline.Infrastructure.Schemas.PipelineConfigSchema
  alias Agents.Repo

  @current_slug "current"

  @spec current_slug() :: String.t()
  def current_slug, do: @current_slug

  @spec get_current(module()) :: {:ok, PipelineConfigSchema.t()} | {:error, :not_found}
  def get_current(repo \\ Repo) do
    case repo.get_by(PipelineConfigSchema, slug: @current_slug) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  @spec upsert_current(map(), module()) ::
          {:ok, PipelineConfigSchema.t()} | {:error, Ecto.Changeset.t()}
  def upsert_current(attrs, repo \\ Repo) when is_map(attrs) do
    attrs = attrs |> normalize_attrs() |> Map.put(:slug, @current_slug)

    case repo.get_by(PipelineConfigSchema, slug: @current_slug) do
      nil ->
        %PipelineConfigSchema{}
        |> PipelineConfigSchema.changeset(attrs)
        |> repo.insert()

      config ->
        config
        |> PipelineConfigSchema.changeset(attrs)
        |> repo.update()
    end
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Enum.map(fn {key, value} -> {normalize_key(key), value} end)
    |> Map.new()
  end

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_existing_atom(key)
end
