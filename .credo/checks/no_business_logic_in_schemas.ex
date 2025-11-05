defmodule Jarga.Credo.Check.Architecture.NoBusinessLogicInSchemas do
  @moduledoc """
  Detects business logic in Ecto schema modules.

  ## SOLID Principle Violation (SRP)

  Ecto schemas are infrastructure layer data structures for persistence.
  They should only handle:
  - Field definitions
  - Database mappings
  - Basic data validation (types, required fields)

  They should NOT contain:
  - Business logic
  - Complex calculations
  - Calls to other services/repositories
  - Cryptographic operations (unless pure validation)

  Per CLAUDE.md lines 88-90: "Keep domain logic in separate domain modules.
  Use changesets only for data validation, not business rules."

  ## Examples

  ### Invalid - Business logic in schema:

      defmodule Jarga.Workspaces.Workspace do
        use Ecto.Schema

        schema "workspaces" do
          field :name, :string
          field :slug, :string
        end

        def changeset(workspace, attrs) do
          workspace
          |> cast(attrs, [:name])
          |> generate_slug()  # ❌ Business logic in schema changeset
        end

        defp generate_slug(changeset) do
          # Slug generation is business logic
          slug = SlugGenerator.generate(name, &MembershipRepository.slug_exists?/2)
          put_change(changeset, :slug, slug)  # ❌ Calls other services
        end
      end

  ### Valid - Pure data validation:

      defmodule Jarga.Workspaces.Workspace do
        use Ecto.Schema

        schema "workspaces" do
          field :name, :string
          field :slug, :string
        end

        def changeset(workspace, attrs) do
          workspace
          |> cast(attrs, [:name, :slug])  # ✅ Just data validation
          |> validate_required([:name, :slug])
          |> validate_length(:name, min: 1, max: 100)
          |> unique_constraint(:slug)
        end
      end

  ### Valid - Business logic in context:

      defmodule Jarga.Workspaces do
        def create_workspace(user, attrs) do
          # Generate slug in context, not schema
          slug = SlugGenerator.generate(attrs["name"], &slug_exists?/1)

          attrs_with_slug = Map.put(attrs, "slug", slug)

          %Workspace{}
          |> Workspace.changeset(attrs_with_slug)
          |> Repo.insert()
        end
      end
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      Ecto schemas should only handle data mapping and basic validation.

      Business logic should be extracted to:
      - Domain modules (pure business rules)
      - Context modules (orchestration)
      - Service objects (complex operations)

      This ensures:
      - Single Responsibility Principle
      - Easier testing (no need to create schemas for business logic tests)
      - Clear separation between data structure and behavior
      - More reusable business logic
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check Ecto schema files
    if schema_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp schema_file?(source_file) do
    content = SourceFile.source(source_file)

    # Check if it's a schema file by looking for "use Ecto.Schema"
    String.contains?(content, "use Ecto.Schema") and
      # Exclude test files
      not String.contains?(source_file.filename, "/test/")
  end

  # Check for calls to external modules/repositories within private functions in changesets
  # Pattern: SomeModule.function_call() within a defp that's likely called from changeset
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if suspicious_business_logic?(module_parts, function) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{format_module(module_parts)}.#{function}",
            "Call to external service/repository"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Check for complex pattern matching in changesets (sign of business logic)
  defp traverse(
         {:defp, meta,
          [
            {function_name, _, _args},
            _body
          ]} = ast,
         issues,
         issue_meta
       )
       when function_name in [:generate_slug, :calculate_total, :compute_score, :process_data] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "defp #{function_name}",
         "Business logic function in schema (#{function_name})"
       )
       | issues
     ]}
  end

  # Check for Bcrypt or cryptographic operations
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Bcrypt]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    # Allow verify_pass as it's more of a validation
    issues =
      if function != :verify_pass do
        [
          issue_for(
            issue_meta,
            meta,
            "Bcrypt.#{function}",
            "Cryptographic operation in schema"
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

  # Detect suspicious calls that indicate business logic
  defp suspicious_business_logic?(module_parts, function) do
    module_name = format_module(module_parts)

    # Check for calls to generators, repositories, or other services
    cond do
      String.ends_with?(module_name, "Generator") -> true
      String.ends_with?(module_name, "Repository") -> true
      String.ends_with?(module_name, "Service") -> true
      String.contains?(module_name, "Queries") -> true
      function in [:exists?, :slug_exists?, :find, :get, :create, :update, :delete] -> true
      true -> false
    end
  end

  defp format_module(module_parts) do
    Enum.join(module_parts, ".")
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Schema contains business logic (#{description}). " <>
          "Ecto schemas should only handle data mapping and basic validation. " <>
          "Move business logic to domain modules or context functions (SOLID/SRP).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
