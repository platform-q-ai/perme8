defmodule Credo.Check.Custom.Architecture.NoApplicationConfigInUseCases do
  @moduledoc """
  Detects Application.get_env calls in use cases that should use dependency injection.

  ## Clean Architecture Violation

  Use cases should receive their dependencies and configuration through explicit
  parameters, not by reading from Application config directly. This creates
  hidden dependencies and makes testing difficult.

  ## Why This Matters

  1. **Testability**: Can't easily override config in tests without Application.put_env
  2. **Explicit Dependencies**: Hidden config access obscures what use case needs
  3. **Purity**: Use cases become dependent on global state
  4. **Flexibility**: Can't easily run same use case with different configurations

  ## Examples

  ### Invalid - Reading config directly in use case:

      defmodule MyApp.Chat.Application.UseCases.PrepareContext do
        def execute(params) do
          # WRONG: Hidden dependency on application config
          max_chars = Application.get_env(:my_app, :chat_context)[:max_content_chars]
          llm_client = Application.get_env(:my_app, :llm_client)

          # ... use these values
        end
      end

  ### Valid - Accept configuration via opts:

      defmodule MyApp.Chat.Application.UseCases.PrepareContext do
        @default_max_chars 3000
        @default_llm_client MyApp.Agents.Infrastructure.Services.LlmClient

        def execute(params, opts \\\\ []) do
          # Explicit dependencies with sensible defaults
          max_chars = Keyword.get(opts, :max_content_chars, @default_max_chars)
          llm_client = Keyword.get(opts, :llm_client, @default_llm_client)

          # ... use these values
        end
      end

      # In tests:
      test "limits content to max chars" do
        result = PrepareContext.execute(params, max_content_chars: 100)
        assert String.length(result.content) <= 100
      end

  ### Valid - Module attribute with compile-time config:

      defmodule MyApp.Chat.Application.UseCases.PrepareContext do
        # OK: Compile-time configuration for module-level settings
        @llm_client Application.compile_env(:my_app, :llm_client, DefaultLlmClient)

        def execute(params, opts \\\\ []) do
          client = Keyword.get(opts, :llm_client, @llm_client)
          # ...
        end
      end

  ## Detected Patterns

  - `Application.get_env/2`, `Application.get_env/3`
  - `Application.fetch_env/2`, `Application.fetch_env!/2`

  ## Allowed Patterns

  - `Application.compile_env/2`, `Application.compile_env/3` (compile-time only)
  - Module attributes with compile_env (evaluated at compile time)
  """

  use Credo.Check,
    base_priority: :normal,
    category: :design,
    explanations: [
      check: """
      Use cases should not call Application.get_env at runtime.

      This creates hidden dependencies and makes testing difficult.
      Use cases should receive configuration through explicit parameters.

      Fix by:
      1. Add configuration as opts parameter with default value
      2. Or use @module_attribute with Application.compile_env for compile-time config
      3. Allow tests to pass different values via opts

      Example:
        def execute(params, opts \\\\ []) do
          max_chars = Keyword.get(opts, :max_chars, 3000)
          # ...
        end
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @runtime_config_functions [:get_env, :fetch_env, :fetch_env!]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    if use_case_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp use_case_file?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "/application/use_cases/") and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
  end

  # Detect Application.get_env, fetch_env, fetch_env! calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Application]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in @runtime_config_functions do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "Application.#{function}",
         "Runtime config access in use case"
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
        "#{description} (#{trigger}). " <>
          "Use cases should receive configuration via opts parameter, not Application config. " <>
          "This enables testing with different configurations. " <>
          "Use: `Keyword.get(opts, :config_key, default_value)` instead.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
