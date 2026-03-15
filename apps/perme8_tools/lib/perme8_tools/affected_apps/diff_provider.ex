defmodule Perme8Tools.AffectedApps.DiffProvider do
  @moduledoc """
  Provides lists of changed files from various sources:
  CLI arguments, git diff, or stdin.
  """

  @doc """
  Returns changed files from explicit CLI arguments.

  Strips whitespace and empty strings.
  """
  @spec from_args([String.t()]) :: [String.t()]
  def from_args(args) when is_list(args) do
    args
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Returns changed files by running `git diff --name-only <base>...HEAD`.

  ## Options

  - `:system_cmd` - injectable function for testing (default: `&System.cmd/3`)
  """
  @spec from_git_diff(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def from_git_diff(base_branch, opts \\ []) do
    system_cmd = Keyword.get(opts, :system_cmd, &System.cmd/3)

    case system_cmd.("git", ["diff", "--name-only", "#{base_branch}...HEAD"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        files =
          output
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        {:ok, files}

      {error_output, _exit_code} ->
        {:error, String.trim(error_output)}
    end
  end

  @doc """
  Reads changed files from stdin, one path per line.

  ## Options

  - `:io_device` - injectable IO device for testing (default: `:stdio`)
  """
  @spec from_stdin(keyword()) :: [String.t()]
  def from_stdin(opts \\ []) do
    io_device = Keyword.get(opts, :io_device, :stdio)

    io_device
    |> IO.read(:eof)
    |> case do
      :eof ->
        []

      {:error, _} ->
        []

      data when is_binary(data) ->
        data
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end
end
