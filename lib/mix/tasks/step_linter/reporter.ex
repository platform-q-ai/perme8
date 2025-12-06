defmodule Mix.Tasks.StepLinter.Reporter do
  @moduledoc """
  Formats and outputs linting results.

  Supports multiple output formats for integration with different tools.
  """
  use Boundary, classify_to: JargaApp

  @doc """
  Reports issues in the specified format.

  Supported formats:
  - "text" (default) - Human-readable output
  - "json" - JSON output for tooling integration
  """
  @spec report([map()], String.t()) :: :ok
  def report(issues, format \\ "text")

  def report([], _format) do
    Mix.shell().info("No issues found.")
    :ok
  end

  def report(issues, "text") do
    issues
    |> Enum.group_by(& &1.file)
    |> Enum.each(fn {file, file_issues} ->
      Mix.shell().info("\n#{file}")
      Mix.shell().info(String.duplicate("-", String.length(file)))

      Enum.each(file_issues, fn issue ->
        severity_color = severity_color(issue.severity)
        severity_label = String.upcase(to_string(issue.severity))

        Mix.shell().info(
          "  #{severity_color}[#{severity_label}]#{IO.ANSI.reset()} Line #{issue.line}: #{issue.message}"
        )

        print_issue_details_if_present(issue)
      end)
    end)

    Mix.shell().info("\n#{summary(issues)}")
    :ok
  end

  def report(issues, "json") do
    json =
      issues
      |> Enum.map(fn issue ->
        %{
          file: issue.file,
          line: issue.line,
          rule: issue.rule,
          severity: issue.severity,
          message: issue.message,
          details: Map.get(issue, :details, %{})
        }
      end)
      |> Jason.encode!(pretty: true)

    Mix.shell().info(json)
    :ok
  end

  def report(issues, _unknown_format) do
    report(issues, "text")
  end

  defp severity_color(:error), do: IO.ANSI.red()
  defp severity_color(:warning), do: IO.ANSI.yellow()
  defp severity_color(:info), do: IO.ANSI.cyan()

  defp print_issue_details_if_present(issue) do
    if Map.has_key?(issue, :details) and map_size(issue.details) > 0 do
      format_details(issue.details)
    end
  end

  defp format_details(details) do
    if Map.has_key?(details, :branches) do
      Enum.each(details.branches, fn branch ->
        Mix.shell().info("    - #{branch.type} at line #{branch.line}")
      end)
    end
  end

  defp summary(issues) do
    error_count = Enum.count(issues, &(&1.severity == :error))
    warning_count = Enum.count(issues, &(&1.severity == :warning))
    info_count = Enum.count(issues, &(&1.severity == :info))

    parts =
      [
        if(error_count > 0, do: "#{error_count} error(s)"),
        if(warning_count > 0, do: "#{warning_count} warning(s)"),
        if(info_count > 0, do: "#{info_count} info")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    "Found: #{parts}"
  end
end
