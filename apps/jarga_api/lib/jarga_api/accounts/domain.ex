defmodule JargaApi.Accounts.Domain do
  @moduledoc """
  Domain layer boundary for the API Accounts context.

  Contains pure domain logic for API key scope operations.
  This layer has no infrastructure dependencies.

  ## Domain Modules

  - `ApiKeyScope` - Interprets API key access scopes in the context of workspaces
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [ApiKeyScope]
end
