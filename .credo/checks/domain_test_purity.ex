defmodule Credo.Check.Custom.Testing.DomainTestPurity do
  @moduledoc """
  Detects domain tests that incorrectly use DataCase instead of pure ExUnit.Case.

  ## Test Pyramid Violation

  Domain layer tests should be pure unit tests with no database access.
  They should use `ExUnit.Case` (not `DataCase` or `ConnCase`) and run
  in milliseconds with `async: true`.

  ```
  1. Domain layer (Start Here):
     - Write tests first using ExUnit.Case
     - No database, no external dependencies
     - Pure logic testing - fastest tests
     - Tests should run in milliseconds
  ```

  (Test Organization):
  ```
  test/
  ├── my_app/
  │   ├── domain/              # Pure unit tests
  │   │   └── policies/
  │   ├── application/         # Use case tests with mocks
  │   │   └── use_cases/
  │   └── infrastructure/      # Integration tests
  ```

  ## Why Domain Tests Should Be Pure

  1. **Speed**: Pure tests run in milliseconds (no database setup/teardown)
  2. **Reliability**: No flakiness from database state
  3. **TDD Feedback**: Fast red-green-refactor cycles
  4. **Parallelism**: Can run fully async with no conflicts
  5. **Clarity**: Separates business logic from infrastructure

  ## Examples

  ### Invalid - DataCase for policy test:

      defmodule Jarga.Pages.Policies.AuthorizationTest do
        use Jarga.DataCase  # ❌ Domain test using DataCase

        alias Jarga.Pages.Policies.Authorization

        test "guest cannot create pages" do
          refute Authorization.can_create_page?(:guest)
        end
      end

  ### Valid - Pure ExUnit.Case for policy test:

      defmodule Jarga.Pages.Policies.AuthorizationTest do
        use ExUnit.Case, async: true  # ✅ Pure unit test

        alias Jarga.Pages.Policies.Authorization

        test "guest cannot create pages" do
          refute Authorization.can_create_page?(:guest)
        end

        test "member can create pages" do
          assert Authorization.can_create_page?(:member)
        end
      end

  ### Valid - DataCase for infrastructure test:

      defmodule Jarga.Pages.Infrastructure.PageRepositoryTest do
        use Jarga.DataCase  # ✅ Infrastructure needs database

        alias Jarga.Pages.Infrastructure.PageRepository

        test "finds pages by workspace" do
          workspace = workspace_fixture()
          page = page_fixture(workspace_id: workspace.id)

          assert [^page] = PageRepository.list_by_workspace(workspace.id)
        end
      end

  ## What Should Use What

  - **Domain tests** (policies, services, value objects): `ExUnit.Case, async: true`
  - **Application tests** (use cases with mocks): `ExUnit.Case` or light `DataCase`
  - **Infrastructure tests** (repositories, queries): `DataCase`
  - **Web tests** (controllers, LiveViews): `ConnCase`

  ## Benefits of Pure Domain Tests

  - 10-100x faster than database tests
  - Can run thousands of tests in seconds
  - Enables true TDD with instant feedback
  - More tests = better coverage
  - Encourages pure functional design
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Domain tests should use ExUnit.Case (not DataCase) for maximum speed.

      Domain layer tests should be pure unit tests that:
      - Use ExUnit.Case with async: true
      - Have no database access
      - Run in milliseconds
      - Test pure business logic

      This ensures:
      - Fast TDD feedback loop
      - Reliable, non-flaky tests
      - True unit testing
      - Proper test pyramid

      Reserve DataCase for infrastructure layer tests that actually need
      database access (repositories, queries, context integration tests).
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check domain test files
    if domain_test_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  # Check if this is a domain test file
  defp domain_test_file?(source_file) do
    filename = source_file.filename

    String.ends_with?(filename, "_test.exs") and
      (String.contains?(filename, "/policies/") or
         String.contains?(filename, "/services/") or
         String.contains?(filename, "test/jarga/") and
           String.contains?(filename, "/domain/"))
  end

  # Detect use Jarga.DataCase or use MyApp.DataCase in domain tests
  defp traverse(
         {:use, meta,
          [
            {:__aliases__, _, module_parts}
          ]} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if data_case_module?(module_parts) do
        [
          issue_for(
            issue_meta,
            meta,
            format_module(module_parts)
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

  # Check if module is a DataCase module
  defp data_case_module?(module_parts) do
    module_name = List.last(module_parts)
    module_name == :DataCase
  end

  defp format_module(module_parts) do
    Enum.join(module_parts, ".")
  end

  defp issue_for(issue_meta, meta, data_case_module) do
    format_issue(
      issue_meta,
      message:
        "Domain test uses #{data_case_module} but should use ExUnit.Case. " <>
          "Domain tests should be pure unit tests with no database access. " <>
          "Replace with: use ExUnit.Case, async: true. " <>
          "Pure domain tests run 10-100x faster and enable true TDD. " <>
          "Reserve DataCase for infrastructure layer tests (repositories, queries).",
      trigger: "use #{data_case_module}",
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
