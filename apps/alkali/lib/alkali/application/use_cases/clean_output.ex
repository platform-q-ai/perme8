defmodule Alkali.Application.UseCases.CleanOutput do
  @moduledoc """
  CleanOutput use case handles deletion of the build output directory.

  This use case orchestrates file system operations to clean up
  the output directory before or after builds.

  Dependencies are injected via the `opts` keyword list.
  """

  # Infrastructure module default - resolved at runtime to avoid boundary violations
  defp default_file_system_mod, do: Alkali.Infrastructure.FileSystem

  @doc """
  Executes the clean output use case.

  ## Options

  - `:file_system` - Function for file system operations (defaults to File module)

  ## Examples

      iex> CleanOutput.execute("_site", file_system: mock_fs)
      :ok

      iex> CleanOutput.execute() # Uses default "_site"
      :ok
  """
  @spec execute(String.t() | keyword(), keyword()) :: :ok | {:error, term()}
  def execute(output_path \\ "_site", opts \\ [])

  def execute(opts, []) when is_list(opts) do
    # Called with just options, use default path
    execute("_site", opts)
  end

  def execute(output_path, opts) when is_binary(output_path) and is_list(opts) do
    file_system = Keyword.get(opts, :file_system, &default_file_system_fn/1)

    case file_system.({:rm_rf, output_path}) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Default implementation delegating to infrastructure
  defp default_file_system_fn({:rm_rf, path}) do
    default_file_system_mod().rm_rf(path)
  end
end
