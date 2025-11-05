defmodule Jarga.Credo.Check.Testing.MissingDomainTests do
  @moduledoc """
  Detects domain modules (policies, services) that are missing test coverage.

  ## TDD Principle Violation

  Per CLAUDE.md: "Always write tests BEFORE implementation code."

  Domain layer modules contain pure business logic and should be the most
  thoroughly tested part of your application. These are the fastest tests
  to run (no database, no I/O) and provide the foundation of the test pyramid.

  Per CLAUDE.md lines 454-467:
  ```
  1. Domain layer (Start Here):
     - Write tests first using ExUnit.Case
     - No database, no external dependencies
     - Pure logic testing - fastest tests
     - Tests should run in milliseconds
     - Test edge cases and business rules thoroughly
  ```

  Per ARCHITECTURE.md lines 636-654: "Test authorization at three levels"
  starting with domain policy level tests.

  ## What Should Be Tested

  Every domain module should have corresponding tests:
  - **Policy modules** (*.Policies.*) - Business rules and authorization
  - **Service modules** (*.Services.*) - Domain operations
  - **Value objects** (*.Domain.*) - Domain primitives

  ## Examples

  ### Missing Test:

      # File exists: lib/jarga/pages/policies/authorization.ex
      # Missing:     test/jarga/pages/policies/authorization_test.exs
      ❌ No test coverage for pure domain logic

  ### Good Coverage:

      # File exists: lib/jarga/workspaces/policies/permissions_policy.ex
      # Test exists: test/jarga/workspaces/policies/permissions_policy_test.exs
      ✅ Domain logic properly tested

  ## Test Organization

  Domain tests should be:
  - Pure ExUnit.Case tests (async: true)
  - No DataCase or ConnCase
  - No database access
  - Fast (milliseconds)
  - Testing all edge cases

  ## Benefits

  Domain layer tests provide:
  - **Fastest feedback loop** during TDD
  - **Complete coverage** of business rules
  - **Living documentation** of domain logic
  - **Confidence in refactoring** without slow integration tests
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      All domain modules should have corresponding test files.

      Domain modules (policies, services, value objects) contain pure
      business logic and should be thoroughly tested. These are the
      fastest tests in the pyramid and should be written FIRST (TDD).

      Missing domain tests indicate:
      - Code written without TDD
      - Untested business logic
      - Missing fastest layer of test pyramid

      Domain tests should:
      - Use ExUnit.Case (not DataCase)
      - Run in milliseconds
      - Test all edge cases
      - Provide comprehensive coverage
      """
    ]

  alias Credo.SourceFile

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    # Only check domain module files
    if domain_module_file?(source_file) and not has_test_file?(source_file) do
      [create_issue(source_file)]
    else
      []
    end
  end

  # Check if this is a domain module file
  defp domain_module_file?(source_file) do
    filename = source_file.filename

    (String.contains?(filename, "/policies/") or
       String.contains?(filename, "/services/") or
       String.contains?(filename, "/domain/")) and
      not String.contains?(filename, "/infrastructure/") and
      not String.ends_with?(filename, "/queries.ex") and
      not String.ends_with?(filename, "_test.exs")
  end

  # Check if a test file exists for the given source file
  defp has_test_file?(source_file) do
    test_path = source_to_test_path(source_file.filename)
    File.exists?(test_path)
  end

  # Convert source path to expected test path
  defp source_to_test_path(source_path) do
    source_path
    |> String.replace("lib/", "test/")
    |> String.replace(".ex", "_test.exs")
  end

  # Create an issue for a missing test
  defp create_issue(source_file) do
    source_path = source_file.filename
    test_path = source_to_test_path(source_path)
    module_name = extract_module_name(source_path)
    module_type = extract_module_type(source_path)

    %Credo.Issue{
      check: __MODULE__,
      category: :warning,
      priority: :high,
      message:
        "Domain module missing test coverage (#{module_type}). " <>
          "Create test file: #{test_path}. " <>
          "Domain tests should be pure ExUnit.Case tests with no database access. " <>
          "Write tests FIRST following TDD (CLAUDE.md). " <>
          "Domain tests are the fastest and most important layer of the test pyramid.",
      filename: source_path,
      line_no: 1,
      trigger: module_name,
      column: nil,
      scope: nil
    }
  end

  # Extract module type from path
  defp extract_module_type(source_path) do
    cond do
      String.contains?(source_path, "/policies/") -> "Policy"
      String.contains?(source_path, "/services/") -> "Service"
      String.contains?(source_path, "/domain/") -> "Domain"
      true -> "Domain"
    end
  end

  # Extract module name from file path
  defp extract_module_name(source_path) do
    source_path
    |> String.split("/")
    |> List.last()
    |> String.replace(".ex", "")
    |> Macro.camelize()
  end
end
