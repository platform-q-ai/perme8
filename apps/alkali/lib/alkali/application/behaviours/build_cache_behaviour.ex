defmodule Alkali.Application.Behaviours.BuildCacheBehaviour do
  @moduledoc """
  Behaviour defining the build cache interface.

  This behaviour abstracts build caching operations for incremental builds,
  allowing the application layer to depend on abstractions rather than
  concrete infrastructure implementations.

  ## Usage

  Infrastructure implementations should implement this behaviour:

      defmodule Alkali.Infrastructure.BuildCache do
        @behaviour Alkali.Application.Behaviours.BuildCacheBehaviour

        @impl true
        def load(site_path), do: # implementation
        # ... other implementations
      end

  Use cases should accept the implementation via options:

      def execute(site_path, opts \\\\ []) do
        build_cache = Keyword.get(opts, :build_cache, Alkali.Infrastructure.BuildCache)
        cache = build_cache.load(site_path)
      end
  """

  @type cache :: map()
  @type file_info :: {integer(), integer()}

  @doc """
  Loads the build cache from disk.

  Returns a map of file paths to their last modification info `{mtime, size}`.
  Returns an empty map if the cache doesn't exist or is invalid.

  ## Options
  - `:file_system` - Module for file operations (default: File)
  """
  @callback load(String.t(), keyword()) :: cache()

  @doc """
  Saves the build cache to disk.

  Returns `:ok` on success or `{:error, term}` on failure.

  ## Options
  - `:file_system` - Module for file operations (default: File)
  """
  @callback save(String.t(), cache(), keyword()) :: :ok | {:error, term()}

  @doc """
  Gets the modification time and size of a file.

  Returns a tuple of `{mtime, size}` for change detection,
  or `nil` if the file doesn't exist.

  ## Options
  - `:file_system` - Module for file operations (default: File)
  """
  @callback get_file_info(String.t(), keyword()) :: file_info() | nil

  @doc """
  Checks if a file has been modified since the last build.

  Compares both modification time and file size for better change detection
  within the same second.

  Returns `true` if the file has changed or is new, `false` otherwise.

  ## Options
  - `:file_system` - Module for file operations (default: File)
  """
  @callback file_changed?(String.t(), cache(), keyword()) :: boolean()

  @doc """
  Updates the cache with current file info (mtime and size).

  Returns the updated cache map.

  ## Options
  - `:file_system` - Module for file operations (default: File)
  """
  @callback update_cache(cache(), list(String.t()), keyword()) :: cache()
end
