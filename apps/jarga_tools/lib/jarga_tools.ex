defmodule JargaTools do
  @moduledoc """
  Development tooling for the Jarga project.

  This app contains Mix tasks and utilities used during development,
  such as the StepLinter for Cucumber step definitions.
  """
  use Boundary,
    top_level?: true,
    deps: []
end
