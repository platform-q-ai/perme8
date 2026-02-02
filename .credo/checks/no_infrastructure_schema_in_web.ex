defmodule Credo.Check.Custom.Architecture.NoInfrastructureSchemaInWeb do
  @moduledoc """
  Detects direct access to infrastructure schemas from the web layer.

  ## Clean Architecture Violation

  The web layer (LiveViews, Controllers, Components) should interact with contexts
  through their public API, not by directly accessing infrastructure schemas.

  Infrastructure schemas are implementation details that should be hidden behind
  the context facade. Direct access creates tight coupling and makes refactoring
  difficult.

  ## Why This Matters

  1. **Encapsulation**: Infrastructure details should be hidden from web layer
  2. **Maintainability**: Schema changes require web layer changes
  3. **Testability**: Can't easily substitute schemas in tests
  4. **Abstraction Leak**: Web layer knows too much about data storage

  ## Examples

  ### Invalid - Direct schema access in LiveView:

      defmodule MyAppWeb.ProjectLive.Show do
        use MyAppWeb, :live_view

        # WRONG: Accessing infrastructure schema directly
        alias MyApp.Projects.Infrastructure.Schemas.ProjectSchema

        def mount(_params, _session, socket) do
          form = to_form(ProjectSchema.changeset(%ProjectSchema{}, %{}))
          {:ok, assign(socket, :form, form)}
        end
      end

  ### Valid - Access via context public API:

      defmodule MyAppWeb.ProjectLive.Show do
        use MyAppWeb, :live_view

        def mount(_params, _session, socket) do
          # Context provides the changeset
          form = to_form(Projects.new_project_changeset())
          {:ok, assign(socket, :form, form)}
        end
      end

      # In the context module:
      defmodule MyApp.Projects do
        alias MyApp.Projects.Infrastructure.Schemas.ProjectSchema

        def new_project_changeset(attrs \\\\ %{}) do
          ProjectSchema.changeset(%ProjectSchema{}, attrs)
        end
      end

  ### Valid - Using domain entities (if exposed by context):

      defmodule MyAppWeb.ProjectLive.Show do
        use MyAppWeb, :live_view

        # OK: Domain entities may be exposed as part of public API
        alias MyApp.Projects.Domain.Entities.Project

        def render(assigns) do
          # Using domain entity for display
        end
      end

  ## Detected Patterns

  - Aliases containing `Infrastructure.Schemas`
  - Direct calls to `*.Infrastructure.Schemas.*` modules
  """

  use Credo.Check,
    base_priority: :normal,
    category: :design,
    explanations: [
      check: """
      Web layer should not directly access infrastructure schemas.

      Infrastructure schemas are implementation details that belong behind
      the context's public API. Direct access creates coupling between
      the web layer and database structure.

      Fix by:
      1. Add a function to the context that returns the changeset
      2. Use that function from the LiveView/Controller
      3. Remove the direct schema alias

      Example:
        # In context:
        def new_project_changeset(attrs \\\\ %{}), do: ProjectSchema.changeset(%ProjectSchema{}, attrs)

        # In LiveView:
        form = to_form(Projects.new_project_changeset())
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    if web_layer_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp web_layer_file?(source_file) do
    filename = source_file.filename

    (String.contains?(filename, "_web/") or
       String.contains?(filename, "/controllers/") or
       String.contains?(filename, "/live/") or
       String.contains?(filename, "/components/")) and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
  end

  # Detect alias of infrastructure schema modules
  defp traverse(
         {:alias, meta, [{:__aliases__, _, module_parts}]} = ast,
         issues,
         issue_meta
       ) do
    module_string = Enum.map(module_parts, &to_string/1) |> Enum.join(".")

    issues =
      if infrastructure_schema?(module_string) do
        [
          issue_for(
            issue_meta,
            meta,
            "alias #{module_string}",
            "Aliasing infrastructure schema in web layer"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect alias with :as option
  defp traverse(
         {:alias, meta, [{:__aliases__, _, module_parts}, [as: _]]} = ast,
         issues,
         issue_meta
       ) do
    module_string = Enum.map(module_parts, &to_string/1) |> Enum.join(".")

    issues =
      if infrastructure_schema?(module_string) do
        [
          issue_for(
            issue_meta,
            meta,
            "alias #{module_string}",
            "Aliasing infrastructure schema in web layer"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect direct calls to infrastructure schema modules
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    module_string = Enum.map(module_parts, &to_string/1) |> Enum.join(".")

    issues =
      if infrastructure_schema?(module_string) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{module_string}.#{function}",
            "Direct infrastructure schema call in web layer"
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

  defp infrastructure_schema?(module_string) do
    String.contains?(module_string, "Infrastructure.Schemas") or
      String.contains?(module_string, ".Infrastructure.Schema.")
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "#{description} (#{trigger}). " <>
          "Web layer should access data through context public API, not infrastructure schemas. " <>
          "Add a function to the context module that provides the changeset/data, " <>
          "then call that function from the web layer.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
