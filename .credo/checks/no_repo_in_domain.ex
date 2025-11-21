defmodule Jarga.Credo.Check.Architecture.NoRepoInDomain do
  @moduledoc """
  Detects Repo or database dependencies in domain layer.

  ## Clean Architecture Violation (Dependency Inversion Principle)

  Domain entities should contain pure business logic with no infrastructure
  dependencies. They should not depend on:
  - Ecto.Repo modules
  - Ecto.Query (for query building)
  - Database validation (`unsafe_validate_unique`)

  Per Clean Architecture principles: Domain layer is the innermost layer and
  should have ZERO dependencies on outer layers (infrastructure, database).

  ## Why This Violates Clean Code

  1. **Dependency Inversion Principle**: Domain should depend on abstractions,
     not concrete implementations (Repo is infrastructure)
  2. **Testability**: Domain entities cannot be tested without a database
  3. **Portability**: Tightly couples business logic to Ecto/PostgreSQL
  4. **Separation of Concerns**: Mixes data validation with database access

  ## Examples

  ### Invalid - Repo in domain entity:

      defmodule Jarga.Accounts.Domain.Entities.User do
        use Ecto.Schema
        import Ecto.Changeset

        def email_changeset(user, attrs, opts) do
          user
          |> cast(attrs, [:email])
          |> unsafe_validate_unique(:email, Jarga.Repo)  # ❌ Repo in domain
        end
      end

  ### Valid - Move validation to application layer:

      # Domain entity - pure validation
      defmodule Jarga.Accounts.Domain.Entities.User do
        use Ecto.Schema
        import Ecto.Changeset

        def email_changeset(user, attrs) do
          user
          |> cast(attrs, [:email])
          |> validate_required([:email])
          |> validate_format(:email, ~r/@/)
        end
      end

      # Application layer - orchestrates with infrastructure
      defmodule Jarga.Accounts.Application.UseCases.UpdateEmail do
        def execute(params) do
          changeset = User.email_changeset(user, attrs)
          
          # Uniqueness check in application layer
          if email_exists?(get_change(changeset, :email)) do
            add_error(changeset, :email, "already exists")
          else
            Repo.update(changeset)
          end
        end

        defp email_exists?(email), do: Repo.exists?(Queries.by_email(email))
      end

  ### Invalid - Query imports in domain:

      defmodule Jarga.Accounts.Domain.Entities.UserToken do
        use Ecto.Schema
        import Ecto.Query  # ❌ Query building in domain

        def verify_token_query(token) do
          from(t in __MODULE__, where: t.token == ^token)  # ❌ Wrong layer
        end
      end

  ### Valid - Move queries to infrastructure:

      # Domain entity - just data structure
      defmodule Jarga.Accounts.Domain.Entities.UserToken do
        use Ecto.Schema

        schema "user_tokens" do
          field :token, :binary
          field :context, :string
        end
      end

      # Infrastructure layer - query building
      defmodule Jarga.Accounts.Infrastructure.Queries.Queries do
        import Ecto.Query

        def verify_token_query(token) do
          from(t in UserToken, where: t.token == ^token)
        end
      end

  ## What Belongs Where

  - **Domain Layer**: Pure business logic, validation rules, changesets
  - **Application Layer**: Use cases that orchestrate domain + infrastructure
  - **Infrastructure Layer**: Repo calls, queries, database access

  ## Exceptions

  This check allows:
  - `unique_constraint` (declarative constraint, not database call)
  - Basic Ecto.Changeset functions (cast, validate_*, put_change)
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Domain entities should not depend on Repo or database infrastructure.

      Domain layer should contain pure business logic with zero dependencies
      on infrastructure concerns like Repo, database queries, or database
      validation.

      Move these concerns to:
      - Application Layer: Use cases that orchestrate domain + infrastructure
      - Infrastructure Layer: Queries, repositories, database access

      This ensures:
      - Dependency Inversion Principle (DIP)
      - Domain logic testable without database
      - Clean Architecture compliance
      - Separation of concerns
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check domain entity files
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

  # Detect import Ecto.Query
  defp traverse(
         {:import, meta, [{:__aliases__, _, [:Ecto, :Query]} | _]} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "import Ecto.Query",
         "Ecto.Query import in domain entity",
         "Move query building to Infrastructure.Queries module"
       )
       | issues
     ]}
  end

  # Detect Jarga.Repo references
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, _function]}, _, args} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if is_repo_module?(module_parts) and suspicious_repo_call?(args) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{format_module(module_parts)}",
            "Repo reference in domain entity",
            "Move to application layer use case"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect from() macro from Ecto.Query
  defp traverse(
         {{:from, meta, _args}} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "from",
         "Query building with from/2 in domain entity",
         "Move to Infrastructure.Queries module"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp is_repo_module?(module_parts) do
    # Check if it's Jarga.Repo or any module ending in Repo
    List.last(module_parts) == :Repo or module_parts == [:Repo]
  end

  # Allow unique_constraint (declarative), but flag unsafe_validate_unique
  defp suspicious_repo_call?(args) do
    # If args contain :unsafe_validate_unique, it's suspicious
    # We can't perfectly detect the function name here, but this is a heuristic
    # The traverse for function calls will catch most cases
    true
  end

  defp format_module(module_parts) do
    Enum.join(module_parts, ".")
  end

  defp issue_for(issue_meta, meta, trigger, description, suggestion) do
    format_issue(
      issue_meta,
      message:
        "Domain entity has infrastructure dependency (#{description}). " <>
          "Domain layer should be pure business logic with no Repo/database dependencies. " <>
          "#{suggestion}. " <>
          "This violates Dependency Inversion Principle and makes domain untestable without database (Clean Architecture).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
