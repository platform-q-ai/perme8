defmodule Credo.Check.Custom.Architecture.NoEctoInDomainLayer do
  @moduledoc """
  Ensures domain layer modules don't depend on Ecto (infrastructure concern).

  ## Clean Architecture Violation

  The domain layer should contain pure business logic with no infrastructure dependencies.
  Ecto is a persistence framework (infrastructure concern) and should not leak into domain.

  Domain entities should be plain structs, not Ecto schemas.
  Validation should use pure functions, not Ecto changesets.

  Per PHOENIX_DESIGN_PRINCIPLES.md:
  - Domain layer is pure business logic
  - No database access
  - No external dependencies
  - Infrastructure depends on domain, not vice versa

  ## Examples

  ### Invalid - Ecto in domain:

      # lib/jarga/agents/domain/entities/agent.ex
      defmodule Jarga.Agents.Domain.Entities.Agent do
        use Ecto.Schema  # ❌ WRONG - Ecto in domain
        import Ecto.Changeset  # ❌ WRONG - Infrastructure concern

        schema "agents" do
          field :name, :string
        end

        def changeset(agent, attrs) do
          agent
          |> cast(attrs, [:name])  # ❌ WRONG - Ecto changeset
          |> validate_required([:name])
        end
      end

  ### Valid - Pure domain entity:

      # lib/jarga/agents/domain/entities/agent.ex
      defmodule Jarga.Agents.Domain.Entities.Agent do
        @moduledoc "Pure domain entity"

        @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t()
        }

        @enforce_keys [:name]
        defstruct [:id, :name]

        @spec new(map()) :: {:ok, t()} | {:error, String.t()}
        def new(%{name: name}) when is_binary(name) do
          {:ok, %__MODULE__{name: name}}
        end
        def new(_), do: {:error, "name is required"}
      end

  ### Valid - Ecto schema in infrastructure:

      # lib/jarga/agents/infrastructure/schemas/agent_schema.ex
      defmodule Jarga.Agents.Infrastructure.Schemas.AgentSchema do
        use Ecto.Schema  # ✅ OK - Infrastructure layer
        import Ecto.Changeset

        alias Jarga.Agents.Domain.Entities.Agent

        schema "agents" do
          field :name, :string
        end

        def changeset(schema, attrs) do
          schema
          |> cast(attrs, [:name])
          |> validate_required([:name])
        end

        @spec to_domain(t()) :: Agent.t()
        def to_domain(%__MODULE__{} = schema) do
          %Agent{id: schema.id, name: schema.name}
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Domain layer must not depend on Ecto (infrastructure concern).

      Move Ecto schemas to infrastructure/schemas/ and create pure
      domain entities as plain structs.

      Benefits:
      - Domain logic testable without database
      - Domain independent of persistence details
      - Easy to swap persistence implementations
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

    # Only check domain layer files
    if domain_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp domain_file?(source_file) do
    path = source_file.filename

    # Check if in domain/ directory
    # Exclude domain behaviour definitions (they can reference Ecto types in specs)
    String.contains?(path, "/domain/") and
      not String.contains?(path, "/test/") and
      not String.ends_with?(path, "_behaviour.ex")
  end

  # Detect: use Ecto.Schema
  defp traverse(
         {:use, meta, [{:__aliases__, _, [:Ecto, :Schema]}]} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "use Ecto.Schema",
         "Ecto.Schema in domain layer - move to infrastructure/schemas/"
       )
       | issues
     ]}
  end

  # Detect: import Ecto.Changeset
  defp traverse(
         {:import, meta, [{:__aliases__, _, [:Ecto, :Changeset]}]} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "import Ecto.Changeset",
         "Ecto.Changeset in domain layer - use pure validation functions"
       )
       | issues
     ]}
  end

  # Detect: alias Ecto.Changeset
  defp traverse(
         {:alias, meta, [{:__aliases__, _, [:Ecto, :Changeset]}]} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "alias Ecto.Changeset",
         "Ecto.Changeset in domain layer - use pure validation functions"
       )
       | issues
     ]}
  end

  # Detect: Ecto.Changeset.cast() calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Ecto, :Changeset]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [:cast, :validate_required, :validate_length, :validate_format] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "Ecto.Changeset.#{function}",
         "Ecto changeset function in domain - use pure validation"
       )
       | issues
     ]}
  end

  # Detect: schema "table_name" blocks
  defp traverse(
         {:schema, meta, [table_name | _]} = ast,
         issues,
         issue_meta
       )
       when is_binary(table_name) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "schema \"#{table_name}\"",
         "Ecto schema definition in domain - move to infrastructure/schemas/"
       )
       | issues
     ]}
  end

  # Detect: changeset/2 function (common Ecto pattern)
  defp traverse(
         {:def, meta, [{:changeset, _, _args} | _]} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "def changeset",
         "Changeset function in domain - move to infrastructure/schemas/"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Domain layer contains Ecto dependency (#{description}). " <>
          "Domain should be pure business logic with no infrastructure dependencies. " <>
          "Move Ecto schemas to infrastructure/schemas/ and create pure domain entities as structs.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
