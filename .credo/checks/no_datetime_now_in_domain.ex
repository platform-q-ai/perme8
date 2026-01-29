defmodule Credo.Check.Custom.Architecture.NoDateTimeNowInDomain do
  @moduledoc """
  Detects non-deterministic DateTime calls in domain layer (policies, entities, services).

  ## Clean Architecture Violation

  Domain layer should contain only pure functions with deterministic behavior.
  Calling `DateTime.utc_now()` or similar functions makes the domain non-deterministic,
  which breaks:

  1. **Testability**: Can't test edge cases (expiration, time boundaries) without mocking
  2. **Purity**: Domain functions should return same output for same input
  3. **Reproducibility**: Can't replay or debug time-sensitive logic

  ## Examples

  ### Invalid - DateTime.utc_now() in policy:

      defmodule MyApp.Accounts.Domain.Policies.TokenPolicy do
        def session_token_expired?(timestamp) do
          # WRONG: Non-deterministic call in domain
          cutoff = DateTime.utc_now() |> DateTime.add(-30, :day)
          DateTime.compare(timestamp, cutoff) == :lt
        end
      end

  ### Valid - Accept current time as parameter:

      defmodule MyApp.Accounts.Domain.Policies.TokenPolicy do
        def session_token_expired?(timestamp, current_time \\\\ DateTime.utc_now()) do
          # OK: Default allows convenience while enabling testing
          cutoff = DateTime.add(current_time, -30, :day)
          DateTime.compare(timestamp, cutoff) == :lt
        end
      end

      # In tests:
      test "token expired after 30 days" do
        old_time = ~U[2024-01-01 00:00:00Z]
        now = ~U[2024-02-01 00:00:00Z]
        assert TokenPolicy.session_token_expired?(old_time, now)
      end

  ### Valid - Inject time via use case:

      defmodule MyApp.Accounts.Application.UseCases.ValidateSession do
        def execute(token, opts \\\\ []) do
          current_time = Keyword.get(opts, :current_time, DateTime.utc_now())
          TokenPolicy.session_token_expired?(token.inserted_at, current_time)
        end
      end

  ## Detected Patterns

  - `DateTime.utc_now/0`, `DateTime.utc_now/1`
  - `DateTime.now/1`, `DateTime.now!/1`
  - `NaiveDateTime.utc_now/0`, `NaiveDateTime.local_now/0`
  - `Date.utc_today/0`
  - `Time.utc_now/0`
  - `:os.system_time/0`, `:os.system_time/1`
  - `System.system_time/0`, `System.system_time/1`
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Domain layer should not call DateTime.utc_now() or similar non-deterministic functions.

      This makes domain logic:
      - Hard to test (can't control time in tests)
      - Non-deterministic (same input, different output)
      - Impure (side effect of reading system clock)

      Fix by accepting current time as a parameter with a default:

          def token_expired?(timestamp, current_time \\\\ DateTime.utc_now())

      Or inject time at the use case level and pass to domain functions.
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @datetime_functions [
    {:DateTime, :utc_now},
    {:DateTime, :now},
    {:DateTime, :now!},
    {:NaiveDateTime, :utc_now},
    {:NaiveDateTime, :local_now},
    {:Date, :utc_today},
    {:Time, :utc_now}
  ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    if domain_layer_file?(source_file) do
      # First, collect line numbers of DateTime calls that are in default arguments
      default_arg_lines = collect_default_arg_datetime_lines(source_file)

      # Then traverse and filter out those in default args
      Code.prewalk(source_file, &traverse(&1, &2, {issue_meta, default_arg_lines}))
    else
      []
    end
  end

  defp domain_layer_file?(source_file) do
    filename = source_file.filename

    (String.contains?(filename, "/domain/policies/") or
       String.contains?(filename, "/domain/entities/") or
       String.contains?(filename, "/domain/services/")) and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
  end

  # Collect line numbers where DateTime calls appear in acceptable patterns:
  # 1. Default arguments: def foo(x, current_time \\ DateTime.utc_now())
  # 2. Keyword.get defaults: Keyword.get(opts, :current_time, DateTime.utc_now())
  defp collect_default_arg_datetime_lines(source_file) do
    ast = Code.ast(source_file)

    {_ast, lines} =
      Macro.prewalk(ast, [], fn
        # Match default arg pattern: {:\\, _, [_var, datetime_call]}
        {:\\, _meta, [_var, datetime_call]} = node, acc ->
          new_lines = extract_datetime_lines(datetime_call, acc)
          {node, new_lines}

        # Match Keyword.get with datetime default: Keyword.get(opts, :key, DateTime.utc_now())
        {{:., _meta, [{:__aliases__, _, [:Keyword]}, :get]}, _call_meta,
         [_opts, _key, datetime_call]} = node,
        acc ->
          new_lines = extract_datetime_lines(datetime_call, acc)
          {node, new_lines}

        node, acc ->
          {node, acc}
      end)

    MapSet.new(lines)
  end

  # Extract line numbers from DateTime calls within an AST
  defp extract_datetime_lines(
         {{:., meta, [{:__aliases__, _, [module]}, function]}, _, _args},
         acc
       ) do
    module_atom = String.to_atom("#{module}")

    if {module_atom, function} in @datetime_functions do
      [Keyword.get(meta, :line, 0) | acc]
    else
      acc
    end
  end

  defp extract_datetime_lines(_other, acc), do: acc

  # Detect DateTime/NaiveDateTime/Date/Time module calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [module]}, function]}, _, _args} = ast,
         issues,
         {issue_meta, default_arg_lines}
       ) do
    module_atom = String.to_atom("#{module}")
    line = Keyword.get(meta, :line, 0)

    issues =
      if {module_atom, function} in @datetime_functions and
           not MapSet.member?(default_arg_lines, line) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{module}.#{function}",
            "Non-deterministic time call in domain layer"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect System.system_time calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:System]}, function]}, _, _args} = ast,
         issues,
         {issue_meta, _default_arg_lines}
       )
       when function in [:system_time, :monotonic_time, :os_time] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "System.#{function}",
         "Non-deterministic time call in domain layer"
       )
       | issues
     ]}
  end

  # Detect :os.system_time calls
  defp traverse(
         {{:., meta, [:os, function]}, _, _args} = ast,
         issues,
         {issue_meta, _default_arg_lines}
       )
       when function in [:system_time, :timestamp] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         ":os.#{function}",
         "Non-deterministic time call in domain layer"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _context) do
    {ast, issues}
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "#{description} (#{trigger}). " <>
          "Domain policies/entities/services should be pure and deterministic. " <>
          "Accept current time as a parameter: `def my_function(arg, current_time \\\\ DateTime.utc_now())` " <>
          "This enables testing time-sensitive logic without mocking.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
