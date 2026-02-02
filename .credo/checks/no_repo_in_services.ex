defmodule Credo.Check.Custom.Architecture.NoRepoInServices do
  @moduledoc """
  Detects direct Repo access in Service modules.

  ## Clean Architecture Violation

  Service modules are domain layer orchestrators that coordinate business logic.
  They should NOT perform data access directly. Data access belongs in the
  infrastructure layer (repositories).

  Per ARCHITECTURE.md:
  ```
  Infrastructure Layer:
  - Data persistence: Ecto schemas, repos, and queries
  - Keep separate from domain: Infrastructure should depend on domain, not vice versa
  ```

  Per CLAUDE.md:
  ```
  Domain Layer (Core Business Logic):
  - Pure business logic: No dependencies on Phoenix, Ecto, or external frameworks
  ```

  ## Layer Responsibilities

  - **Domain Services**: Orchestrate business logic, coordinate domain entities
  - **Infrastructure Repositories**: Perform data access, abstract database queries
  - **Contexts**: Coordinate between domain and infrastructure

  ## Examples

  ### Invalid - Service accessing Repo:

      defmodule Jarga.Pages.Services.ComponentLoader do
        alias Jarga.Repo

        # ❌ Service performing data access
        def load_component("note", id) do
          Repo.get(Jarga.Notes.Note, id)
        end
      end

  ### Valid - Extract to Repository:

      defmodule Jarga.Pages.Infrastructure.ComponentRepository do
        alias Jarga.Repo

        # ✅ Repository handles data access
        def get_component("note", id) do
          Repo.get(Jarga.Notes.Note, id)
        end

        def get_component("task_list", id) do
          Repo.get(Jarga.Pages.TaskList, id)
        end

        def get_component(_, _), do: nil
      end

      defmodule Jarga.Pages.Services.ComponentLoader do
        alias Jarga.Pages.Infrastructure.ComponentRepository

        # ✅ Service delegates to repository
        def load_component(type, id) do
          ComponentRepository.get_component(type, id)
        end
      end

  ## Why Services Shouldn't Access Repo

  1. **Violates Clean Architecture**: Domain depends on infrastructure
  2. **Hard to test**: Requires database for unit tests
  3. **Confuses responsibilities**: Service vs Repository roles unclear
  4. **Not reusable**: Tied to specific database implementation

  ## Benefits of Repository Pattern

  - **Testability**: Mock repositories in service tests
  - **Separation of concerns**: Clear domain vs infrastructure boundary
  - **Flexibility**: Easy to swap data sources
  - **Consistency**: Uniform data access pattern
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      Service modules should not access Repo directly.

      Services are domain layer modules that orchestrate business logic.
      Data access should be delegated to repository modules in the
      infrastructure layer.

      Pattern:
      - Service coordinates domain logic
      - Service calls Repository for data
      - Repository accesses Repo/database

      This ensures:
      - Clean Architecture compliance
      - Domain layer remains pure
      - Better testability
      - Clear separation of concerns
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check service modules
    if service_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  # Check if this is a service module file
  defp service_file?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "/services/") and
      not String.ends_with?(filename, "_test.exs")
  end

  # Detect Repo.get/get!/get_by/etc calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if repo_function?(module_parts, function) do
        [
          issue_for(
            issue_meta,
            meta,
            "Repo.#{function}",
            "direct Repo.#{function}() call"
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

  # Check if this is a Repo data access function
  defp repo_function?(module_parts, function) do
    List.last(module_parts) == :Repo and
      function in [
        :get,
        :get!,
        :get_by,
        :get_by!,
        :all,
        :one,
        :one!,
        :insert,
        :update,
        :delete,
        :insert_all,
        :update_all,
        :delete_all,
        :preload
      ]
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Service contains direct Repo access (#{description}). " <>
          "Extract to Repository module in infrastructure layer. " <>
          "Services should orchestrate domain logic, not perform data access. " <>
          "This violates Clean Architecture - domain should not depend on infrastructure (DIP).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
