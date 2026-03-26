defmodule Agents.Pipeline.Application.PipelineConfigStore do
  @moduledoc false

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PipelineConfig

  @spec load(Path.t() | nil, keyword()) :: {:ok, PipelineConfig.t()} | {:error, [String.t()]}
  def load(path \\ nil, opts \\ []) when is_nil(path) or is_binary(path) do
    parser = Keyword.get(opts, :parser, PipelineRuntimeConfig.pipeline_parser())

    case source_mode(path, opts) do
      :file -> parser.parse_file(path)
      :repo -> load_from_repo(opts)
    end
  end

  @spec fetch_document(Path.t() | nil, keyword()) ::
          {:ok, %{config: PipelineConfig.t()}} | {:error, [String.t()]}
  def fetch_document(path \\ nil, opts \\ []) when is_nil(path) or is_binary(path) do
    parser = Keyword.get(opts, :parser, PipelineRuntimeConfig.pipeline_parser())

    case source_mode(path, opts) do
      :file ->
        with {:ok, config} <- parser.parse_file(path), do: {:ok, %{config: config}}

      :repo ->
        with {:ok, config} <- safe_get_current(repo_module(opts)), do: {:ok, %{config: config}}
    end
  end

  @spec persist_config(PipelineConfig.t(), Path.t() | nil, keyword()) ::
          :ok | {:error, String.t() | [String.t()]}
  def persist_config(%PipelineConfig{} = config, path \\ nil, opts \\ []) do
    case source_mode(path, opts) do
      :file -> persist_file_config(config, path, opts)
      :repo -> persist_repo_config(config, opts)
    end
  end

  defp load_from_repo(opts) do
    case safe_get_current(repo_module(opts)) do
      {:ok, config} ->
        {:ok, config}

      {:error, :not_found} ->
        {:error, ["pipeline config not found in Agents.Repo"]}

      {:error, reason} ->
        {:error, ["unable to load pipeline config from Agents.Repo: #{inspect(reason)}"]}
    end
  end

  defp persist_repo_config(config, opts) do
    case safe_upsert_current(repo_module(opts), config) do
      {:ok, _record} -> :ok
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset_error_messages(changeset)}
      {:error, :repo_unavailable} -> {:error, "Agents.Repo is unavailable"}
      {:error, reason} -> {:error, "failed to persist pipeline config: #{inspect(reason)}"}
    end
  end

  defp persist_file_config(config, path, opts) do
    writer = Keyword.get(opts, :writer, PipelineRuntimeConfig.pipeline_writer())

    with {:ok, yaml} <- writer.dump(config),
         :ok <- write_yaml(path, yaml, Keyword.get(opts, :file_io, File)) do
      :ok
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

  defp write_yaml(path, yaml, %{write: write_fun}) when is_function(write_fun, 2),
    do: write_fun.(path, yaml)

  defp write_yaml(path, yaml, file_module) do
    case file_module.write(path, yaml) do
      :ok -> :ok
      {:error, reason} -> {:error, "failed to write pipeline config document: #{inspect(reason)}"}
    end
  end

  defp source_mode(path, opts) do
    case Keyword.get(opts, :pipeline_source, :auto) do
      nil -> if(is_nil(path), do: :repo, else: :file)
      :file -> :file
      :repo -> :repo
      :auto -> if(is_nil(path), do: :repo, else: :file)
    end
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
