defmodule CredoChecks.CleanArchitecture.BoundaryPackageInstalled do
  @moduledoc """
  Checks that the `boundary` package is installed in the app's mix.exs.

  The boundary library provides compile-time enforcement of architectural
  boundaries, ensuring that modules only depend on modules they're allowed
  to depend on according to Clean Architecture principles.

  ## Why This Matters

  Without the boundary library, architectural violations can silently creep
  into the codebase. The boundary library catches these at compile time,
  preventing:

  - Domain layer depending on infrastructure
  - Application layer directly importing infrastructure (bypassing DI)
  - Cross-boundary module access

  ## Configuration

  This check can be configured with:

  - `:exit_status` - The exit status to use (default: 2)

  ## Example

      # .credo.exs
      {CredoChecks.CleanArchitecture.BoundaryPackageInstalled, []}
  """

  use Credo.Check,
    id: "EX7001",
    base_priority: :high,
    category: :design,
    exit_status: 2,
    explanations: [
      check: """
      The `boundary` package should be installed to enforce Clean Architecture
      boundaries at compile time.

      Add to your mix.exs deps:

          {:boundary, "~> 0.10", runtime: false}

      Then define boundaries in your layer modules using `use Boundary`.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Only check mix.exs files
    if Path.basename(filename) == "mix.exs" do
      issue_meta = IssueMeta.for(source_file, params)
      check_for_boundary_dep(source_file, issue_meta)
    else
      []
    end
  end

  defp check_for_boundary_dep(source_file, issue_meta) do
    source = SourceFile.source(source_file)

    # Check if {:boundary, ...} is present in the deps
    if String.contains?(source, "{:boundary,") do
      []
    else
      # Check if this is an app mix.exs (has `app:` key)
      if String.contains?(source, "app:") do
        [issue_for(issue_meta, source_file.filename)]
      else
        []
      end
    end
  end

  defp issue_for(issue_meta, filename) do
    format_issue(
      issue_meta,
      message:
        "Clean Architecture: The `boundary` package is not installed. Add `{:boundary, \"~> 0.10\", runtime: false}` to deps.",
      trigger: "mix.exs",
      filename: filename,
      line_no: 1
    )
  end
end
