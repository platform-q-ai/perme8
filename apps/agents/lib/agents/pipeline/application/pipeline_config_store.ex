defmodule Agents.Pipeline.Application.PipelineConfigStore do
  @moduledoc false

  alias Agents.Pipeline.Application.DefaultPipelineConfig
  alias Agents.Pipeline.Application.PipelineRuntimeConfig

  @spec load(Path.t() | nil, keyword()) ::
          {:ok, Agents.Pipeline.Domain.Entities.PipelineConfig.t()} | {:error, [String.t()]}
  def load(path \\ nil, opts \\ []) when is_nil(path) or is_binary(path) do
    parser = Keyword.get(opts, :parser, PipelineRuntimeConfig.pipeline_parser())

    case source_mode(path, opts) do
      :file -> parser.parse_file(path)
      :repo -> load_from_repo(path, parser, opts)
    end
  end

  @spec fetch_document(Path.t() | nil, keyword()) ::
          {:ok, %{config: Agents.Pipeline.Domain.Entities.PipelineConfig.t(), yaml: String.t()}}
          | {:error, [String.t()]}
  def fetch_document(path \\ nil, opts \\ []) when is_nil(path) or is_binary(path) do
    parser = Keyword.get(opts, :parser, PipelineRuntimeConfig.pipeline_parser())

    case source_mode(path, opts) do
      :file ->
        with {:ok, config} <- parser.parse_file(path),
             {:ok, yaml} <- read_yaml(path, Keyword.get(opts, :file_io, File)) do
          {:ok, %{config: config, yaml: yaml}}
        end

      :repo ->
        fetch_repo_document(path, parser, opts)
    end
  end

  @spec persist(String.t(), Path.t() | nil, keyword()) ::
          :ok | {:error, String.t() | [String.t()]}
  def persist(yaml, path \\ nil, opts \\ [])
      when is_binary(yaml) and (is_nil(path) or is_binary(path)) do
    case source_mode(path, opts) do
      :file -> write_yaml(path, yaml, Keyword.get(opts, :file_io, File))
      :repo -> persist_repo_yaml(yaml, opts)
    end
  end

  defp load_from_repo(path, parser, opts) do
    with {:ok, %{config: config}} <- fetch_repo_document(path, parser, opts) do
      {:ok, config}
    end
  end

  defp fetch_repo_document(path, parser, opts) do
    repo_module =
      Keyword.get(opts, :pipeline_config_repo, PipelineRuntimeConfig.pipeline_config_repository())

    case safe_get_current(repo_module) do
      {:ok, record} ->
        parse_repo_yaml(record.yaml, parser)

      {:error, :not_found} ->
        bootstrap_default_document(parser, repo_module, opts)

      {:error, reason} ->
        fallback_repo_error(reason, path, parser, opts)
    end
  end

  defp parse_repo_yaml(yaml, parser) do
    with {:ok, config} <- parser.parse_string(yaml) do
      {:ok, %{config: config, yaml: yaml}}
    end
  end

  defp bootstrap_default_document(parser, repo_module, opts) do
    with {:ok, yaml} <- default_yaml(opts),
         {:ok, config} <- parser.parse_string(yaml),
         :ok <- maybe_persist_bootstrap_yaml(yaml, repo_module) do
      {:ok, %{config: config, yaml: yaml}}
    else
      {:error, errors} when is_list(errors) -> {:error, errors}
      {:error, reason} -> {:error, [to_string(reason)]}
    end
  end

  defp fallback_repo_error(reason, path, parser, opts) do
    case path do
      binary_path when is_binary(binary_path) ->
        with {:ok, config} <- parser.parse_file(binary_path),
             {:ok, yaml} <- read_yaml(binary_path, Keyword.get(opts, :file_io, File)) do
          {:ok, %{config: config, yaml: yaml}}
        else
          {:error, _errors} ->
            {:error, ["unable to load pipeline config from Agents.Repo: #{inspect(reason)}"]}
        end

      nil ->
        with {:ok, yaml} <- default_yaml(opts),
             {:ok, config} <- parser.parse_string(yaml) do
          {:ok, %{config: config, yaml: yaml}}
        else
          {:error, _errors} ->
            {:error, ["unable to load pipeline config from Agents.Repo: #{inspect(reason)}"]}
        end
    end
  end

  defp maybe_persist_bootstrap_yaml(yaml, repo_module) do
    case safe_upsert_current(repo_module, %{yaml: yaml}) do
      {:ok, _record} ->
        :ok

      {:error, :repo_unavailable} ->
        :ok

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset_error_messages(changeset)}

      {:error, reason} ->
        {:error, "unable to bootstrap pipeline config into Agents.Repo: #{inspect(reason)}"}
    end
  end

  defp persist_repo_yaml(yaml, opts) do
    repo_module =
      Keyword.get(opts, :pipeline_config_repo, PipelineRuntimeConfig.pipeline_config_repository())

    case safe_upsert_current(repo_module, %{yaml: yaml}) do
      {:ok, _record} -> :ok
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset_error_messages(changeset)}
      {:error, :repo_unavailable} -> {:error, "Agents.Repo is unavailable"}
      {:error, reason} -> {:error, "failed to persist pipeline config: #{inspect(reason)}"}
    end
  end

  defp safe_get_current(repo_module) do
    if is_nil(repo_module), do: raise(RuntimeError, "pipeline config repo unavailable")
    repo_module.get_current()
  rescue
    DBConnection.ConnectionError -> {:error, :repo_unavailable}
    RuntimeError -> {:error, :repo_unavailable}
  end

  defp safe_upsert_current(repo_module, attrs) do
    if is_nil(repo_module), do: raise(RuntimeError, "pipeline config repo unavailable")
    repo_module.upsert_current(attrs)
  rescue
    DBConnection.ConnectionError -> {:error, :repo_unavailable}
    RuntimeError -> {:error, :repo_unavailable}
  end

  defp read_yaml(path, %{read: read_fun}) when is_function(read_fun, 1), do: read_fun.(path)
  defp read_yaml(path, %{write: _write_fun}), do: read_yaml(path, File)

  defp read_yaml(path, file_module) do
    case file_module.read(path) do
      {:ok, yaml} ->
        {:ok, yaml}

      {:error, reason} ->
        {:error, ["unable to read pipeline config document #{path}: #{inspect(reason)}"]}
    end
  end

  defp default_yaml(opts) do
    case Keyword.get(opts, :bootstrap_yaml) do
      yaml when is_binary(yaml) -> {:ok, yaml}
      _ -> {:ok, DefaultPipelineConfig.yaml()}
    end
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
