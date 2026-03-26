defmodule Agents.Pipeline.Application.PipelineConfigStore do
  @moduledoc false

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PipelineConfig

  @spec load(keyword()) :: {:ok, PipelineConfig.t()} | {:error, [String.t()]}
  def load(opts \\ []) do
    case safe_get_current(repo_module(opts)) do
      {:ok, config} ->
        {:ok, config}

      {:error, :not_found} ->
        {:error, ["pipeline config not found in Agents.Repo"]}

      {:error, reason} ->
        {:error, ["unable to load pipeline config from Agents.Repo: #{inspect(reason)}"]}
    end
  end

  @spec fetch_document(keyword()) :: {:ok, %{config: PipelineConfig.t()}} | {:error, [String.t()]}
  def fetch_document(opts \\ []) do
    with {:ok, config} <- safe_get_current(repo_module(opts)) do
      {:ok, %{config: config}}
    else
      {:error, :not_found} ->
        {:error, ["pipeline config not found in Agents.Repo"]}

      {:error, reason} ->
        {:error, ["unable to load pipeline config from Agents.Repo: #{inspect(reason)}"]}
    end
  end

  @spec persist_config(PipelineConfig.t(), keyword()) :: :ok | {:error, String.t() | [String.t()]}
  def persist_config(%PipelineConfig{} = config, opts \\ []) do
    case safe_upsert_current(repo_module(opts), config) do
      {:ok, _record} -> :ok
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset_error_messages(changeset)}
      {:error, :repo_unavailable} -> {:error, "Agents.Repo is unavailable"}
      {:error, reason} -> {:error, "failed to persist pipeline config: #{inspect(reason)}"}
    end
  end

  defp repo_module(opts) do
    Keyword.get(opts, :pipeline_config_repo, PipelineRuntimeConfig.pipeline_config_repository())
  end

  defp safe_get_current(repo_module) do
    if is_nil(repo_module), do: raise(RuntimeError, "pipeline config repo unavailable")
    repo_module.get_current()
  rescue
    DBConnection.ConnectionError -> {:error, :repo_unavailable}
    RuntimeError -> {:error, :repo_unavailable}
  end

  defp safe_upsert_current(repo_module, config) do
    if is_nil(repo_module), do: raise(RuntimeError, "pipeline config repo unavailable")
    repo_module.upsert_current(config)
  rescue
    DBConnection.ConnectionError -> {:error, :repo_unavailable}
    RuntimeError -> {:error, :repo_unavailable}
  end

  defp changeset_error_messages(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
  end
end
