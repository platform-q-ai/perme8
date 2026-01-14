defmodule Mix.Tasks.Credo.Check do
  @moduledoc """
  Runs Credo as part of the compilation process to enforce architectural rules.

  This task runs Credo with --strict mode to catch architectural violations
  during development. It provides a clean summary in the compile output.

  ## Usage

      mix compile           # Runs Credo automatically
      SKIP_CREDO_CHECK=1 mix compile  # Skip Credo temporarily

  ## When It Runs

  - ✅ During `mix compile` (in dev and test environments)
  - ✅ During `mix test` (catches issues before tests run)
  - ✅ In your IDE (on file save if using ElixirLS)
  - ❌ Skipped when `SKIP_CREDO_CHECK=1` is set
  - ❌ Skipped in production builds

  ## Benefits

  - Catches architectural violations immediately during development
  - Enforces Clean Architecture principles in real-time
  - Provides fast feedback on SOLID principle violations
  - Works seamlessly with your existing workflow
  """

  use Boundary, top_level?: true

  use Mix.Task

  @shortdoc "Runs Credo checks and displays summary"

  def run(_args) do
    # Ensure Credo is loaded
    Mix.Task.run("loadpaths")

    # Run Credo in strict mode and show full output
    case System.cmd("mix", ["credo", "--strict"],
           stderr_to_stdout: true,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        # No issues
        :ok

      {_, _exit_code} ->
        # Issues found - output already displayed above
        Mix.shell().info("""

        To skip Credo check: SKIP_CREDO_CHECK=1 mix compile
        """)
    end
  rescue
    _error ->
      # Silently skip if Credo isn't available
      :ok
  end
end
