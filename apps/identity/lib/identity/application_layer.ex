defmodule Identity.ApplicationLayer do
  @moduledoc """
  Application layer namespace for the Identity application.

  The Identity app uses Clean Architecture with domain, application,
  and infrastructure layers. This module provides documentation and
  introspection for the application layer.

  ## Application Layer Principles

  The application layer orchestrates business operations by:

  - Coordinating domain entities and policies
  - Defining the public API for identity operations
  - Implementing use cases (single-responsibility operations)
  - Depending on abstractions (behaviours) for infrastructure

  ## Use Case Pattern

  All use cases in Identity follow a consistent pattern:

  ```elixir
  defmodule Identity.Application.UseCases.DoSomething do
    def execute(params, opts \\\\ []) do
      # 1. Validate input
      # 2. Apply domain policies
      # 3. Coordinate with repositories (via injection)
      # 4. Return {:ok, result} or {:error, reason}
    end
  end
  ```

  ## Dependency Rules

  Application layer modules:
  - MUST depend only on domain layer entities and policies
  - MUST use dependency injection for infrastructure concerns
  - MUST NOT directly call Repo, File, or external services
  - MAY define behaviours for infrastructure implementations
  """

  use Boundary, top_level?: true, deps: [], exports: []

  @doc """
  Lists all use case modules in the Identity application.

  ## Examples

      iex> Identity.ApplicationLayer.use_cases()
      [Identity.Application.UseCases.RegisterUser, ...]
  """
  @spec use_cases() :: [module()]
  def use_cases do
    [
      Identity.Application.UseCases.RegisterUser,
      Identity.Application.UseCases.LoginByMagicLink,
      Identity.Application.UseCases.GenerateSessionToken,
      Identity.Application.UseCases.DeliverLoginInstructions,
      Identity.Application.UseCases.DeliverUserUpdateEmailInstructions,
      Identity.Application.UseCases.UpdateUserPassword,
      Identity.Application.UseCases.UpdateUserEmail,
      Identity.Application.UseCases.CreateApiKey,
      Identity.Application.UseCases.ListApiKeys,
      Identity.Application.UseCases.UpdateApiKey,
      Identity.Application.UseCases.RevokeApiKey,
      Identity.Application.UseCases.VerifyApiKey
    ]
  end

  @doc """
  Lists all application service modules in the Identity application.

  ## Examples

      iex> Identity.ApplicationLayer.services()
      [Identity.Application.Services.PasswordService, ...]
  """
  @spec services() :: [module()]
  def services do
    [
      Identity.Application.Services.PasswordService,
      Identity.Application.Services.ApiKeyTokenService
    ]
  end

  @doc """
  Lists all behaviour modules defined in the Identity application layer.

  ## Examples

      iex> Identity.ApplicationLayer.behaviours()
      [Identity.Application.Behaviours.UserRepositoryBehaviour, ...]
  """
  @spec behaviours() :: [module()]
  def behaviours do
    [
      Identity.Application.Behaviours.UserRepositoryBehaviour,
      Identity.Application.Behaviours.UserTokenRepositoryBehaviour,
      Identity.Application.Behaviours.UserSchemaBehaviour,
      Identity.Application.Behaviours.UserNotifierBehaviour,
      Identity.Application.Behaviours.ApiKeyRepositoryBehaviour,
      Identity.Application.Behaviours.TokenGeneratorBehaviour,
      Identity.Application.Behaviours.QueriesBehaviour
    ]
  end

  @doc """
  Returns a count summary of application layer modules.

  ## Examples

      iex> Identity.ApplicationLayer.summary()
      %{use_cases: 12, services: 2, behaviours: 7, total: 21}
  """
  @spec summary() :: map()
  def summary do
    use_case_count = length(use_cases())
    service_count = length(services())
    behaviour_count = length(behaviours())

    %{
      use_cases: use_case_count,
      services: service_count,
      behaviours: behaviour_count,
      total: use_case_count + service_count + behaviour_count
    }
  end
end
