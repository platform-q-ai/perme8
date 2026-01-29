defmodule Alkali.Application.Behaviours.FileSystemBehaviour do
  @moduledoc """
  Behaviour defining the file system interface.

  This behaviour abstracts file system operations, allowing the application layer
  to depend on abstractions rather than concrete infrastructure implementations.
  This follows the Dependency Inversion Principle of Clean Architecture.

  ## Usage

  Infrastructure implementations should implement this behaviour:

      defmodule Alkali.Infrastructure.FileSystem do
        @behaviour Alkali.Application.Behaviours.FileSystemBehaviour

        @impl true
        def read(path), do: File.read(path)
        # ... other implementations
      end

  Use cases should accept the implementation via options:

      def execute(path, opts \\\\ []) do
        file_system = Keyword.get(opts, :file_system, Alkali.Infrastructure.FileSystem)
        file_system.read(path)
      end
  """

  @type path :: Path.t()
  @type posix_error :: File.posix()

  @doc """
  Reads content from a file.

  Returns `{:ok, binary}` on success or `{:error, posix}` on failure.
  """
  @callback read(path()) :: {:ok, binary()} | {:error, posix_error()}

  @doc """
  Writes content to a file.

  Returns `:ok` on success or `{:error, posix}` on failure.
  """
  @callback write(path(), iodata()) :: :ok | {:error, posix_error()}

  @doc """
  Writes content to a file and returns the path on success.

  Creates parent directories if they don't exist.
  Returns `{:ok, path}` on success or `{:error, posix}` on failure.
  """
  @callback write_with_path(path(), iodata()) :: {:ok, path()} | {:error, posix_error()}

  @doc """
  Creates a directory and all parent directories.

  Returns `:ok` on success or `{:error, posix}` on failure.
  """
  @callback mkdir_p(path()) :: :ok | {:error, posix_error()}

  @doc """
  Creates a directory and returns the path on success.

  Returns `{:ok, path}` on success or `{:error, posix}` on failure.
  """
  @callback mkdir_p_with_path(path()) :: {:ok, path()} | {:error, posix_error()}

  @doc """
  Creates a directory and all parents, raising on error.

  Returns `:ok` on success.
  """
  @callback mkdir_p!(path()) :: :ok

  @doc """
  Removes a file or directory recursively.

  Returns `:ok` on success or `{:error, posix}` on failure.
  """
  @callback rm_rf(path()) :: :ok | {:error, posix_error()}

  @doc """
  Gets file stats.

  Returns `{:ok, File.Stat.t()}` on success or `{:error, posix}` on failure.
  """
  @callback stat(path()) :: {:ok, File.Stat.t()} | {:error, posix_error()}

  @doc """
  Gets file stats, raising on error.

  Returns `File.Stat.t()` on success.
  """
  @callback stat!(path()) :: File.Stat.t()

  @doc """
  Finds all files matching a glob pattern.

  Returns a list of matching paths.
  """
  @callback wildcard(path()) :: [path()]

  @doc """
  Checks if a path exists.

  Returns `true` if the path exists, `false` otherwise.
  """
  @callback exists?(path()) :: boolean()

  @doc """
  Checks if a path is a directory.

  Returns `true` if the path is a directory, `false` otherwise.
  """
  @callback dir?(path()) :: boolean()

  @doc """
  Checks if a path is a regular file.

  Returns `true` if the path is a regular file, `false` otherwise.
  """
  @callback regular?(path()) :: boolean()

  @doc """
  Lists files in a directory.

  Returns `{:ok, [path]}` on success or `{:error, posix}` on failure.
  """
  @callback ls(path()) :: {:ok, [path()]} | {:error, posix_error()}

  @doc """
  Loads markdown content files from a directory.

  Returns a list of tuples containing file path, content, and modification time.
  Returns `{:ok, [{path, content, mtime}]}` on success or `{:error, reason}` on failure.
  """
  @callback load_markdown_files(path()) ::
              {:ok, [{path(), binary(), NaiveDateTime.t()}]} | {:error, String.t()}
end
