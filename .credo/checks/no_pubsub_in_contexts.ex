defmodule Credo.Check.Custom.Architecture.NoPubSubInContexts do
  @moduledoc """
  Detects direct PubSub broadcasting in context modules.

  ## Single Responsibility Principle Violation

  Context modules should focus on business logic and data access. Broadcasting
  notifications is an infrastructure concern that should be extracted to a
  separate service.

  ## Clean Architecture Principle

  Following the Dependency Inversion Principle, contexts should depend on
  abstractions (behaviors) for notifications, not concrete implementations
  like Phoenix.PubSub.

  ## Examples

  ### Invalid - Direct PubSub in context:

      defmodule Jarga.Pages do
        def update_page(page, attrs) do
          with {:ok, page} <- Repo.update(changeset) do
            Phoenix.PubSub.broadcast(...)  # ❌ Infrastructure in domain
            {:ok, page}
          end
        end
      end

  ### Valid - Use EventBus via dependency injection:

      defmodule Jarga.Pages.Application.UseCases.UpdatePage do
        @default_event_bus Perme8.Events.EventBus

        def execute(params, opts \\\\ []) do
          event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

          with {:ok, page} <- Repo.update(changeset) do
            event_bus.emit(%PageUpdated{  # ✅ Structured event via EventBus
              aggregate_id: page.id,
              actor_id: params.user.id
            })
            {:ok, page}
          end
        end
      end
  """

  use Credo.Check,
    base_priority: :normal,
    category: :design,
    explanations: [
      check: """
      Context modules should not directly use Phoenix.PubSub.

      Use the EventBus via dependency injection instead:
        event_bus = Keyword.get(opts, :event_bus, Perme8.Events.EventBus)
        event_bus.emit(%MyEvent{...})

      See lib/jarga/projects/application/use_cases/create_project.ex for an
      example of the correct pattern.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check context modules (lib/jarga/*/), not web layer or services
    if should_check_file?(source_file) do
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp should_check_file?(source_file) do
    filename = source_file.filename

    # Must be in lib/jarga/ (handles both absolute and relative paths)
    in_jarga = String.contains?(filename, "lib/jarga/")
    # Must NOT be in lib/jarga_web/
    not_in_web = not String.contains?(filename, "lib/jarga_web/")
    # Must NOT be in services/ subdirectories (notifiers are allowed to use PubSub)
    not_in_services = not String.contains?(filename, "/services/")
    # Must NOT be in infrastructure/ subdirectories (infrastructure layer can use PubSub)
    not_in_infrastructure = not String.contains?(filename, "/infrastructure/")
    # Must NOT be credo check files themselves
    not_check_file = not String.contains?(filename, "lib/credo/")

    in_jarga and not_in_web and not_in_services and not_in_infrastructure and not_check_file
  end

  # Match any function call with module.function pattern
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function_name]}, _, _} = ast,
         issues,
         issue_meta
       ) do
    new_issues =
      if pubsub_call?(module_parts, function_name) do
        [issue_for(issue_meta, meta, function_name) | issues]
      else
        issues
      end

    {ast, new_issues}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp pubsub_call?(module_parts, function_name)
       when is_list(module_parts) and is_atom(function_name) do
    module_parts == [:Phoenix, :PubSub] and function_name in [:broadcast, :broadcast_from]
  end

  defp pubsub_call?(_, _), do: false

  defp issue_for(issue_meta, meta, function_name) do
    trigger = "Phoenix.PubSub.#{function_name}"

    format_issue(
      issue_meta,
      message:
        "Context modules should not directly use #{trigger}. Use EventBus via opts[:event_bus] dependency injection instead.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
