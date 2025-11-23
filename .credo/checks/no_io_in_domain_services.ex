defmodule Jarga.Credo.Check.Architecture.NoIoInDomainServices do
  @moduledoc """
  Ensures domain services contain only pure business logic with no I/O operations.

  ## Clean Architecture Violation

  Domain services must be pure functions with no side effects.
  They should not perform any I/O operations (database, HTTP, files, etc.).

  Per PHOENIX_DESIGN_PRINCIPLES.md:
  - Domain layer is pure business logic
  - No database access
  - No HTTP calls
  - No file I/O
  - No system calls
  - Testable in milliseconds without external dependencies

  ## Examples

  ### Invalid - I/O in domain service:

      # lib/jarga/agents/domain/services/context_builder.ex
      defmodule Jarga.Agents.Domain.Services.ContextBuilder do
        alias Jarga.Repo  # ❌ WRONG - Database access

        def build_context(workspace_id) do
          workspace = Repo.get(Workspace, workspace_id)  # ❌ WRONG - I/O in domain
          format_workspace(workspace)
        end
      end

  ### Valid - Pure domain service:

      # lib/jarga/agents/domain/services/context_builder.ex
      defmodule Jarga.Agents.Domain.Services.ContextBuilder do
        @doc "Pure function - no I/O, easily testable"
        def build_context(workspace) do  # ✅ OK - Receives data, doesn't fetch it
          %{
            workspace_name: workspace.name,
            formatted_text: format_workspace(workspace)
          }
        end

        defp format_workspace(ws) do  # ✅ OK - Pure transformation
          "Workspace: " <> ws.name
        end
      end

  ### Valid - Use case coordinates I/O:

      # lib/jarga/agents/application/use_cases/queries/prepare_chat_context.ex
      defmodule Jarga.Agents.Application.UseCases.Queries.PrepareChatContext do
        alias Jarga.Workspaces.Infrastructure.Repositories.WorkspaceRepository
        alias Jarga.Agents.Domain.Services.ContextBuilder

        def execute(workspace_id) do
          # Use case fetches data (I/O)
          workspace = WorkspaceRepository.get_workspace(workspace_id)

          # Domain service does pure transformation
          ContextBuilder.build_context(workspace)  # ✅ OK - Delegates to pure domain logic
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Domain services must be pure functions with no I/O operations.

      Domain services should only:
      - Transform data
      - Apply business rules
      - Perform calculations
      - Validate input

      Move I/O to:
      - Application layer (use cases orchestrate I/O)
      - Infrastructure layer (repositories, clients)

      Benefits:
      - Domain logic testable in milliseconds
      - No external dependencies required for tests
      - Domain independent of infrastructure
      - Follows Dependency Inversion Principle
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check domain service files
    if domain_service_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp domain_service_file?(source_file) do
    path = source_file.filename

    # Check if in domain/services/ directory
    String.contains?(path, "/domain/services/") and
      not String.contains?(path, "/test/")
  end

  # Detect: Repo usage
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [
              :insert,
              :insert!,
              :update,
              :update!,
              :delete,
              :delete!,
              :get,
              :get!,
              :get_by,
              :all,
              :one,
              :transaction
            ] do
    issues =
      if repo_module?(module_parts) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{format_module(module_parts)}.#{function}",
            "Database I/O in domain service"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect: HTTP client calls
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
            "HTTP I/O in domain service"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect: File I/O
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
         "File I/O in domain service"
       )
       | issues
     ]}
  end

  # Detect: PubSub broadcasts
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [:broadcast, :broadcast!, :subscribe, :unsubscribe] do
    issues =
      if pubsub_module?(module_parts) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{format_module(module_parts)}.#{function}",
            "PubSub I/O in domain service"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect: System calls
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
         "System call in domain service"
       )
       | issues
     ]}
  end

  # Detect: GenServer calls (async I/O)
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:GenServer]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [:call, :cast, :start_link] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "GenServer.#{function}",
         "Process I/O in domain service"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  # Check if module is a Repo
  defp repo_module?(module_parts) do
    module_name = format_module(module_parts)
    String.ends_with?(module_name, "Repo") or String.ends_with?(module_name, "Repository")
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

  # Check if module is PubSub
  defp pubsub_module?(module_parts) do
    module_name = format_module(module_parts)
    String.contains?(module_name, "PubSub")
  end

  defp format_module(module_parts) do
    Enum.join(module_parts, ".")
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Domain service contains I/O operation (#{description}). " <>
          "Domain services must be pure functions with no side effects. " <>
          "Move I/O to application layer (use cases orchestrate) or infrastructure layer. " <>
          "Domain should receive data as parameters, not fetch it.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
