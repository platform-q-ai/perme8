defmodule Credo.Check.Custom.Architecture.NoInfrastructureInDomainEntities do
  @moduledoc """
  Detects direct infrastructure module calls in domain entities.

  ## Clean Architecture Violation (Dependency Rule)

  Domain entities are the innermost layer of Clean Architecture and must have
  ZERO dependencies on outer layers. They should contain only:
  - Pure data structures
  - Validation logic
  - Business rules (as pure functions)

  Domain entities must NOT:
  - Call infrastructure modules directly
  - Import/alias infrastructure modules
  - Depend on external services (crypto, file system, HTTP, etc.)

  ## Why This Matters

  1. **Dependency Rule**: Inner layers cannot depend on outer layers
  2. **Testability**: Entities become hard to test with infrastructure dependencies
  3. **Portability**: Ties domain to specific infrastructure implementations
  4. **Single Responsibility**: Entities should only model business concepts

  ## Examples

  ### Invalid - Entity calls infrastructure:

      defmodule MyApp.Domain.Entities.Asset do
        alias MyApp.Infrastructure.CryptoService

        def calculate_fingerprint(content) do
          # WRONG: Domain entity calling infrastructure
          CryptoService.sha256_fingerprint(content)
        end
      end

  ### Valid - Use case orchestrates infrastructure:

      defmodule MyApp.Domain.Entities.Asset do
        defstruct [:path, :content, :fingerprint]

        # Pure function - receives fingerprint, doesn't calculate it
        def with_fingerprint(%__MODULE__{} = asset, fingerprint) do
          %{asset | fingerprint: fingerprint}
        end
      end

      defmodule MyApp.Application.UseCases.ProcessAssets do
        alias MyApp.Infrastructure.CryptoService

        def execute(asset, opts \\\\ []) do
          crypto = Keyword.get(opts, :crypto_service, CryptoService)
          fingerprint = crypto.sha256_fingerprint(asset.content)
          Asset.with_fingerprint(asset, fingerprint)
        end
      end

  ## Detected Patterns

  - Direct calls to `*.Infrastructure.*` modules
  - Aliases of infrastructure modules in domain entities
  - Calls to infrastructure services (CryptoService, FileSystem, etc.)
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Domain entities must not call infrastructure modules directly.

      This violates the Clean Architecture Dependency Rule:
      - Domain (innermost) cannot depend on Infrastructure (outer layer)

      Fix by:
      1. Remove the infrastructure call from the entity
      2. Move the logic to a use case that orchestrates domain + infrastructure
      3. Pass computed values into the entity as parameters

      Example fix:
        # Before (wrong):
        def calculate_fingerprint(content) do
          Infrastructure.CryptoService.sha256_fingerprint(content)
        end

        # After (correct):
        # In use case:
        fingerprint = crypto_service.sha256_fingerprint(content)
        Asset.with_fingerprint(asset, fingerprint)
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  # Generic infrastructure patterns that apply across all apps
  @infrastructure_patterns [
    ".Infrastructure.",
    "Infrastructure."
  ]

  # Common infrastructure service names (without namespace)
  @infrastructure_services [
    "Repo",
    "CryptoService",
    "FileSystem",
    "ConfigLoader",
    "LayoutResolver",
    "BuildCache",
    "HttpClient",
    "EmailService",
    "StorageService",
    "CacheService",
    "QueueService"
  ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    if domain_entity_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp domain_entity_file?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "/domain/entities/") and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
  end

  # Detect alias of infrastructure modules
  defp traverse(
         {:alias, meta, [{:__aliases__, _, module_parts}]} = ast,
         issues,
         issue_meta
       ) do
    module_string = Enum.map(module_parts, &to_string/1) |> Enum.join(".")

    issues =
      if infrastructure_module?(module_string) do
        [
          issue_for(
            issue_meta,
            meta,
            "alias #{module_string}",
            "Aliasing infrastructure module in domain entity"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect direct calls to infrastructure modules (fully qualified)
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    module_string = Enum.map(module_parts, &to_string/1) |> Enum.join(".")

    issues =
      if infrastructure_module?(module_string) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{module_string}.#{function}",
            "Direct infrastructure call in domain entity"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp infrastructure_module?(module_string) do
    # Check for Infrastructure namespace pattern
    infrastructure_namespace? =
      Enum.any?(@infrastructure_patterns, fn pattern ->
        String.contains?(module_string, pattern)
      end)

    # Check for common infrastructure service names
    infrastructure_service? =
      Enum.any?(@infrastructure_services, fn service ->
        String.ends_with?(module_string, service) or
          String.ends_with?(module_string, ".#{service}")
      end)

    infrastructure_namespace? or infrastructure_service?
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Domain entity has infrastructure dependency (#{description}). " <>
          "Domain entities must be pure with zero infrastructure dependencies. " <>
          "Move infrastructure calls to use cases and pass computed values as parameters. " <>
          "This violates the Clean Architecture Dependency Rule.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
