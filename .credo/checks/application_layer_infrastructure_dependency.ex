defmodule Jarga.Credo.Check.Architecture.ApplicationLayerInfrastructureDependency do
  @moduledoc """
  Detects infrastructure concerns (I/O operations) in the application layer.

  ## Clean Architecture Violation

  Application layer should orchestrate domain logic, not perform I/O operations.
  I/O operations (HTTP calls, file access, external APIs) belong in infrastructure layer.

  Per PHOENIX_DESIGN_PRINCIPLES.md:
  - Application layer: Use cases, policies (pure orchestration)
  - Infrastructure layer: External APIs, HTTP clients, file I/O, databases

  ## Examples

  ### Invalid - HTTP calls in application layer:

      # lib/jarga/agents/application/services/llm_client.ex
      defmodule Jarga.Agents.Application.Services.LlmClient do
        def query(prompt) do
          HTTPoison.post(  # ❌ WRONG - HTTP I/O in application layer
            "https://api.openrouter.ai/v1/chat/completions",
            Jason.encode!(payload)
          )
        end
      end

  ### Valid - HTTP client in infrastructure:

      # lib/jarga/agents/infrastructure/services/llm_client.ex
      defmodule Jarga.Agents.Infrastructure.Services.LlmClient do
        @behaviour Jarga.Agents.Infrastructure.Services.Behaviours.LlmClientBehaviour

        def query(prompt) do
          HTTPoison.post(  # ✅ OK - Infrastructure layer
            "https://api.openrouter.ai/v1/chat/completions",
            Jason.encode!(payload)
          )
        end
      end

  ### Valid - Use case delegates to infrastructure:

      # lib/jarga/agents/application/use_cases/queries/execute_agent_query.ex
      defmodule Jarga.Agents.Application.UseCases.Queries.ExecuteAgentQuery do
        @llm_client Application.compile_env(:jarga, :llm_client)

        def execute(params) do
          # Orchestrates domain logic, delegates I/O to infrastructure
          @llm_client.query(params.prompt)  # ✅ OK - Delegates to injected dependency
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Application layer should not contain I/O operations - move to infrastructure.

      I/O operations to move:
      - HTTP client calls (HTTPoison, Req, Finch, etc.)
      - File operations (File.read, File.write, etc.)
      - External API clients
      - System calls

      Benefits:
      - Application layer remains testable with mocks
      - Clear separation of concerns
      - Easy to swap implementations
      - Follows Clean Architecture
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check application layer files (excluding policies which should be pure)
    if application_layer_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp application_layer_file?(source_file) do
    path = source_file.filename

    # Check if in application/ directory but not policies (policies should be pure)
    String.contains?(path, "/application/") and
      not String.contains?(path, "/application/policies/") and
      not String.contains?(path, "/test/")
  end

  # Detect HTTP client usage
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [:get, :post, :put, :delete, :patch, :request] do
    issues =
      if http_client?(module_parts) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{format_module(module_parts)}.#{function}",
            "HTTP client call in application layer"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect File I/O operations
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:File]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [:read, :read!, :write, :write!, :open, :mkdir, :rm, :rm_rf] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "File.#{function}",
         "File I/O in application layer"
       )
       | issues
     ]}
  end

  # Detect System calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:System]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [:cmd, :shell] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "System.#{function}",
         "System call in application layer"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  # Check if module is an HTTP client
  defp http_client?(module_parts) do
    module_name = format_module(module_parts)

    module_name in [
      "HTTPoison",
      "Req",
      "Finch",
      "HTTPClient",
      "Tesla",
      "Mint"
    ]
  end

  defp format_module(module_parts) do
    Enum.join(module_parts, ".")
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Application layer contains I/O operation (#{description}). " <>
          "I/O operations should be in infrastructure layer (infrastructure/services/). " <>
          "Application layer should orchestrate domain logic and delegate I/O to infrastructure dependencies. " <>
          "This ensures testability (mock I/O) and follows Clean Architecture.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
