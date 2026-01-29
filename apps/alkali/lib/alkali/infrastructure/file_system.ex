defmodule Alkali.Infrastructure.FileSystem do
  @moduledoc """
  Infrastructure service for file system operations.

  This module provides a clean interface for file system operations,
  keeping I/O concerns isolated from the application and domain layers.
  """

  @doc """
  Reads content from a file.

  ## Examples

      iex> FileSystem.read("path/to/file.txt")
      {:ok, "content"}

      iex> FileSystem.read("nonexistent.txt")
      {:error, :enoent}
  """
  @spec read(Path.t()) :: {:ok, binary()} | {:error, File.posix()}
  def read(path) do
    File.read(path)
  end

  @doc """
  Writes content to a file.

  ## Examples

      iex> FileSystem.write("path/to/file.txt", "content")
      :ok
  """
  @spec write(Path.t(), iodata()) :: :ok | {:error, File.posix()}
  def write(path, content) do
    File.write(path, content)
  end

  @doc """
  Writes content to a file and returns the path on success.

  Creates parent directories if they don't exist.

  ## Examples

      iex> FileSystem.write_with_path("path/to/file.txt", "content")
      {:ok, "path/to/file.txt"}
  """
  @spec write_with_path(Path.t(), iodata()) :: {:ok, Path.t()} | {:error, File.posix()}
  def write_with_path(path, content) do
    with :ok <- mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, content) do
      {:ok, path}
    end
  end

  @doc """
  Creates a directory and all parent directories.

  ## Examples

      iex> FileSystem.mkdir_p("path/to/dir")
      :ok
  """
  @spec mkdir_p(Path.t()) :: :ok | {:error, File.posix()}
  def mkdir_p(path) do
    File.mkdir_p(path)
  end

  @doc """
  Creates a directory and returns the path on success.

  ## Examples

      iex> FileSystem.mkdir_p_with_path("path/to/dir")
      {:ok, "path/to/dir"}
  """
  @spec mkdir_p_with_path(Path.t()) :: {:ok, Path.t()} | {:error, File.posix()}
  def mkdir_p_with_path(path) do
    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes a file or directory recursively.

  ## Examples

      iex> FileSystem.rm_rf("path/to/dir")
      :ok
  """
  @spec rm_rf(Path.t()) :: :ok | {:error, File.posix()}
  def rm_rf(path) do
    case File.rm_rf(path) do
      {:ok, _files} -> :ok
      {:error, reason, _file} -> {:error, reason}
    end
  end

  @doc """
  Gets file stats.

  ## Examples

      iex> FileSystem.stat("path/to/file.txt")
      {:ok, %File.Stat{}}
  """
  @spec stat(Path.t()) :: {:ok, File.Stat.t()} | {:error, File.posix()}
  def stat(path) do
    File.stat(path)
  end

  @doc """
  Gets file stats, raising on error.

  ## Examples

      iex> FileSystem.stat!("path/to/file.txt")
      %File.Stat{}
  """
  @spec stat!(Path.t()) :: File.Stat.t()
  def stat!(path) do
    File.stat!(path)
  end

  @doc """
  Finds all files matching a glob pattern.

  ## Examples

      iex> FileSystem.wildcard("path/**/*.md")
      ["path/file1.md", "path/subdir/file2.md"]
  """
  @spec wildcard(Path.t()) :: [Path.t()]
  def wildcard(pattern) do
    Path.wildcard(pattern)
  end

  @doc """
  Checks if a path exists.

  ## Examples

      iex> FileSystem.exists?("path/to/file.txt")
      true
  """
  @spec exists?(Path.t()) :: boolean()
  def exists?(path) do
    File.exists?(path)
  end

  @doc """
  Checks if a path is a directory.

  ## Examples

      iex> FileSystem.dir?("path/to/dir")
      true
  """
  @spec dir?(Path.t()) :: boolean()
  def dir?(path) do
    File.dir?(path)
  end

  @doc """
  Checks if a path is a regular file.

  ## Examples

      iex> FileSystem.regular?("path/to/file.txt")
      true
  """
  @spec regular?(Path.t()) :: boolean()
  def regular?(path) do
    File.regular?(path)
  end

  @doc """
  Lists files in a directory.

  ## Examples

      iex> FileSystem.ls("path/to/dir")
      {:ok, ["file1.txt", "file2.txt"]}
  """
  @spec ls(Path.t()) :: {:ok, [Path.t()]} | {:error, File.posix()}
  def ls(path) do
    File.ls(path)
  end

  @doc """
  Creates a directory and all parents, raising on error.

  ## Examples

      iex> FileSystem.mkdir_p!("path/to/dir")
      :ok
  """
  @spec mkdir_p!(Path.t()) :: :ok
  def mkdir_p!(path) do
    File.mkdir_p!(path)
  end

  @doc """
  Loads markdown content files from a directory.

  Returns a list of tuples containing file path, content, and modification time.

  ## Examples

      iex> FileSystem.load_markdown_files("content/")
      {:ok, [{"content/post.md", "# Title", ~N[2024-01-01 00:00:00]}]}
  """
  @spec load_markdown_files(Path.t()) ::
          {:ok, [{Path.t(), binary(), NaiveDateTime.t()}]} | {:error, String.t()}
  def load_markdown_files(path) do
    pattern = Path.join(path, "**/*.md")
    md_files = wildcard(pattern)

    results =
      Enum.map(md_files, fn file_path ->
        case read(file_path) do
          {:ok, content} ->
            mtime = stat!(file_path).mtime
            {:ok, {file_path, content, mtime}}

          {:error, reason} ->
            {:error, "Failed to read #{file_path}: #{inspect(reason)}"}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, &elem(&1, 1))}
    else
      {:error, hd(errors) |> elem(1)}
    end
  end
end
