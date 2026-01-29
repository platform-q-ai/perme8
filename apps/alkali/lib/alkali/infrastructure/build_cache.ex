defmodule Alkali.Infrastructure.BuildCache do
  @moduledoc """
  Manages build cache for incremental builds.

  Tracks file modification times to determine which files need rebuilding.

  Implements the `Alkali.Application.Behaviours.BuildCacheBehaviour` to allow
  dependency injection and testability in use cases.
  """

  @behaviour Alkali.Application.Behaviours.BuildCacheBehaviour

  @cache_file ".alkali_cache.json"

  @doc """
  Loads the build cache from disk.

  Returns a map of file paths to their last modification info {mtime, size}.
  """
  @impl true
  @spec load(String.t()) :: map()
  def load(site_path) do
    cache_path = Path.join(site_path, @cache_file)

    with true <- File.exists?(cache_path),
         {:ok, content} <- File.read(cache_path),
         {:ok, json_cache} <- Jason.decode(content) do
      parse_cache_entries(json_cache)
    else
      _ -> %{}
    end
  end

  defp parse_cache_entries(json_cache) do
    Map.new(json_cache, fn
      {path, [mtime, size]} -> {path, {mtime, size}}
      {path, mtime} when is_integer(mtime) -> {path, {mtime, 0}}
    end)
  end

  @doc """
  Saves the build cache to disk.
  """
  @impl true
  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(site_path, cache) do
    cache_path = Path.join(site_path, @cache_file)

    # Convert tuples to lists for JSON encoding
    json_cache =
      Map.new(cache, fn {path, {mtime, size}} ->
        {path, [mtime, size]}
      end)

    case Jason.encode(json_cache, pretty: true) do
      {:ok, json} -> File.write(cache_path, json)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the modification time and size of a file.

  Returns a tuple of {mtime, size} for change detection.
  Using both mtime (second precision) and size helps detect changes
  that happen within the same second.
  """
  @impl true
  @spec get_file_info(String.t()) :: {integer(), integer()} | nil
  def get_file_info(file_path) do
    case File.stat(file_path, time: :posix) do
      {:ok, %File.Stat{mtime: mtime, size: size}} ->
        {mtime, size}

      {:error, _} ->
        nil
    end
  end

  @doc """
  Checks if a file has been modified since the last build.

  Compares both modification time and file size for better change detection
  within the same second.
  """
  @impl true
  @spec file_changed?(String.t(), map()) :: boolean()
  def file_changed?(file_path, cache) do
    current_info = get_file_info(file_path)
    cached_info = Map.get(cache, file_path)

    cond do
      # File doesn't exist anymore
      is_nil(current_info) -> false
      # No cache entry - file is new
      is_nil(cached_info) -> true
      # Compare both mtime and size
      true -> current_info != cached_info
    end
  end

  @doc """
  Updates the cache with current file info (mtime and size).
  """
  @impl true
  @spec update_cache(map(), list(String.t())) :: map()
  def update_cache(cache, file_paths) do
    Enum.reduce(file_paths, cache, fn file_path, acc ->
      case get_file_info(file_path) do
        nil -> acc
        info -> Map.put(acc, file_path, info)
      end
    end)
  end
end
