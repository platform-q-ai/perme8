defmodule Perme8Tools do
  @moduledoc """
  Development tooling for the Perme8 project.

  This app contains Mix tasks and utilities used during development,
  such as the StepLinter for BDD step definitions and the exo-bdd test runner.
  """
  use Boundary,
    top_level?: true,
    deps: []
end
