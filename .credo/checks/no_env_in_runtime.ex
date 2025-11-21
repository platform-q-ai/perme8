defmodule Jarga.Credo.Check.Architecture.NoEnvInRuntime do
  @moduledoc """
  Detects runtime System.get_env calls that should use Application config.

  ## Clean Code Violation (Dependency Injection)

  Runtime environment variable access couples code to the environment and makes
  testing difficult. Configuration should be:
  - Loaded at compile/startup time via Application config
  - Injected as function parameters
  - Provided via configuration structs

  Per Clean Architecture: Dependencies should be injected, not fetched.

  ## Why This Violates Clean Code

  1. **Testability**: Hard to test with different configurations
  2. **Dependency Inversion**: Code depends on environment, not abstractions
  3. **Coupling**: Tightly couples to System environment
  4. **Consistency**: Config spread across codebase instead of centralized

  ## Examples

  ### Invalid - Runtime env access in infrastructure:

      defmodule Jarga.Accounts.Infrastructure.Notifiers.UserNotifier do
        defp deliver(recipient, subject, body) do
          # ❌ Fetching env at runtime
          from_email = System.get_env("SENDGRID_FROM_EMAIL", "noreply@jarga.app")
          from_name = System.get_env("SENDGRID_FROM_NAME", "Jarga")

          new()
          |> from({from_name, from_email})
          |> to(recipient)
          |> subject(subject)
          |> text_body(body)
        end
      end

  ### Valid - Use Application config:

      # config/runtime.exs
      config :jarga, Jarga.Mailer,
        adapter: Swoosh.Adapters.Sendgrid,
        from_email: System.get_env("SENDGRID_FROM_EMAIL") || "noreply@jarga.app",
        from_name: System.get_env("SENDGRID_FROM_NAME") || "Jarga"

      # lib/jarga/accounts/infrastructure/notifiers/user_notifier.ex
      defmodule Jarga.Accounts.Infrastructure.Notifiers.UserNotifier do
        # ✅ Read config at compile/startup time
        @from_email Application.compile_env(:jarga, [Jarga.Mailer, :from_email])
        @from_name Application.compile_env(:jarga, [Jarga.Mailer, :from_name])

        defp deliver(recipient, subject, body) do
          new()
          |> from({@from_name, @from_email})
          |> to(recipient)
          |> subject(subject)
          |> text_body(body)
        end
      end

  ### Valid - Inject as parameter:

      defmodule Jarga.Accounts.Infrastructure.Notifiers.UserNotifier do
        # ✅ Configuration injected as parameter
        def deliver(recipient, subject, body, opts \\ []) do
          from_email = Keyword.get(opts, :from_email, default_from_email())
          from_name = Keyword.get(opts, :from_name, default_from_name())

          new()
          |> from({from_name, from_email})
          |> to(recipient)
          |> subject(subject)
          |> text_body(body)
        end

        defp default_from_email do
          Application.get_env(:jarga, :from_email, "noreply@jarga.app")
        end

        defp default_from_name do
          Application.get_env(:jarga, :from_name, "Jarga")
        end
      end

  ## Allowed Locations

  **Runtime env access IS allowed in:**
  - `config/runtime.exs` (config files)
  - `lib/jarga/release.ex` (runtime initialization)
  - Mix tasks in `lib/mix/tasks/`

  **Runtime env access NOT allowed in:**
  - Domain entities
  - Application use cases
  - Infrastructure services (notifiers, repositories)
  - Web controllers/LiveViews

  ## Alternative Approaches

  1. **Compile-time config** (best for static values):
     ```elixir
     @from_email Application.compile_env(:jarga, :from_email)
     ```

  2. **Runtime config** (for dynamic values):
     ```elixir
     Application.get_env(:jarga, :from_email)
     ```

  3. **Dependency injection** (best for testability):
     ```elixir
     def notify(user, opts \\ []) do
       from_email = Keyword.fetch!(opts, :from_email)
       # ...
     end
     ```
  """

  use Credo.Check,
    base_priority: :low,
    category: :warning,
    explanations: [
      check: """
      Runtime System.get_env calls should use Application config instead.

      Instead of fetching environment variables at runtime, use:
      - Application.compile_env/2 for compile-time config
      - Application.get_env/3 for runtime config (loaded at startup)
      - Dependency injection via function parameters

      This ensures:
      - Easier testing (mock config, not environment)
      - Centralized configuration
      - Dependency injection
      - Better error handling (config validates at startup)

      Runtime env access is allowed only in:
      - config/runtime.exs
      - lib/[app]/release.ex
      - lib/mix/tasks/
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Skip allowed files
    if runtime_env_allowed?(source_file) do
      []
    else
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end
  end

  # Runtime env access allowed in these files
  defp runtime_env_allowed?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "config/runtime.exs") or
      String.contains?(filename, "/release.ex") or
      String.contains?(filename, "lib/mix/tasks/") or
      String.contains?(filename, "/test/")
  end

  # Detect System.get_env calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:System]}, :get_env]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "System.get_env"
       )
       | issues
     ]}
  end

  # Also detect System.fetch_env!
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:System]}, :fetch_env!]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "System.fetch_env!"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, meta, trigger) do
    format_issue(
      issue_meta,
      message:
        "Runtime environment variable access with #{trigger}. " <>
          "Use Application config instead: Application.get_env/3 or Application.compile_env/2. " <>
          "For config that needs env vars, set them in config/runtime.exs and read with Application config. " <>
          "This improves testability and centralizes configuration (Dependency Injection).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
