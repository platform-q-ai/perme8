defmodule Credo.Check.Custom.Architecture.InfrastructureOrganization do
  @moduledoc """
  Ensures infrastructure layer files are organized into proper subdirectories.

  This check enforces Clean Architecture by ensuring infrastructure modules are:
  1. Organized by responsibility (repositories, queries, notifiers, subscribers)
  2. Not scattered at the infrastructure root or context root
  3. Easy to navigate and understand

  ## Rules

  1. Files named `*_repository.ex` → `infrastructure/repositories/`
  2. Files named `queries.ex` or `*_queries.ex` → `infrastructure/queries/`
  3. Files named `*_notifier.ex` → `infrastructure/notifiers/`
  4. Files named `*_subscriber.ex` → `infrastructure/subscribers/`

  ## Current Violations

  Infrastructure files not organized:
  - `lib/jarga/accounts/queries.ex` → `infrastructure/queries/queries.ex`
  - `lib/jarga/agents/infrastructure/agent_repository.ex` → `infrastructure/repositories/`

  ## Expected Structure

      lib/jarga/{context}/
      └── infrastructure/
          ├── repositories/      # Database access
          │   └── *_repository.ex
          ├── queries/           # Ecto query composition
          │   └── queries.ex
          ├── notifiers/         # External notifications
          │   └── *_notifier.ex
          └── subscribers/       # PubSub subscribers
              └── *_subscriber.ex

  ## Configuration

      {Credo.Check.Custom.Architecture.InfrastructureOrganization, []}

  """

  use Credo.Check,
    base_priority: :normal,
    category: :design,
    explanations: [
      check: """
      Infrastructure files should be organized into subdirectories by responsibility.

      This makes the codebase easier to navigate and understand.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    file_path = source_file.filename

    # Only check infrastructure-related files
    if is_infrastructure_file?(file_path) do
      check_file_organization(file_path, issue_meta)
    else
      []
    end
  end

  # Check if this is an infrastructure file that needs organization
  defp is_infrastructure_file?(file_path) do
    file_name = Path.basename(file_path)

    # Check for infrastructure patterns
    (String.ends_with?(file_name, "_repository.ex") or
       String.match?(file_name, ~r|^.*queries?\.ex$|) or
       String.ends_with?(file_name, "_notifier.ex") or
       String.ends_with?(file_name, "_subscriber.ex")) and
      String.contains?(file_path, "lib/jarga/") and
      not String.contains?(file_path, "test/") and
      not String.contains?(file_path, "jarga_web")
  end

  # Verify file is in correct subdirectory
  defp check_file_organization(file_path, issue_meta) do
    file_name = Path.basename(file_path)

    cond do
      # Repositories
      String.ends_with?(file_name, "_repository.ex") ->
        check_repository_location(file_path, issue_meta)

      # Queries
      String.match?(file_name, ~r|^.*queries?\.ex$|) ->
        check_queries_location(file_path, issue_meta)

      # Notifiers (handled by ServicesInCorrectLayer, but double-check)
      String.ends_with?(file_name, "_notifier.ex") ->
        check_notifier_location(file_path, issue_meta)

      # Subscribers
      String.ends_with?(file_name, "_subscriber.ex") ->
        check_subscriber_location(file_path, issue_meta)

      true ->
        []
    end
  end

  # Check repository location
  defp check_repository_location(file_path, issue_meta) do
    if String.match?(file_path, ~r|/infrastructure/repositories/[^/]+\.ex$|) do
      []
    else
      correct_path =
        String.replace(
          file_path,
          ~r|(lib/jarga/[^/]+)/(?:infrastructure/)?([^/]+_repository\.ex)$|,
          "\\1/infrastructure/repositories/\\2"
        )

      [
        create_issue(
          issue_meta,
          "Repository not in infrastructure/repositories/",
          correct_path,
          1
        )
      ]
    end
  end

  # Check queries location
  defp check_queries_location(file_path, issue_meta) do
    if String.match?(file_path, ~r|/infrastructure/queries/[^/]+\.ex$|) do
      []
    else
      file_name = Path.basename(file_path)
      context = extract_context(file_path)
      correct_path = "lib/jarga/#{context}/infrastructure/queries/#{file_name}"

      [
        create_issue(
          issue_meta,
          "Queries module not in infrastructure/queries/",
          correct_path,
          1
        )
      ]
    end
  end

  # Check notifier location  
  defp check_notifier_location(file_path, issue_meta) do
    if String.match?(file_path, ~r|/infrastructure/notifiers/[^/]+\.ex$|) do
      []
    else
      file_name = Path.basename(file_path)
      context = extract_context(file_path)
      correct_path = "lib/jarga/#{context}/infrastructure/notifiers/#{file_name}"

      [
        create_issue(
          issue_meta,
          "Notifier not in infrastructure/notifiers/",
          correct_path,
          1
        )
      ]
    end
  end

  # Check subscriber location
  defp check_subscriber_location(file_path, issue_meta) do
    if String.match?(file_path, ~r|/infrastructure/subscribers/[^/]+\.ex$|) do
      []
    else
      file_name = Path.basename(file_path)
      context = extract_context(file_path)
      correct_path = "lib/jarga/#{context}/infrastructure/subscribers/#{file_name}"

      [
        create_issue(
          issue_meta,
          "Subscriber not in infrastructure/subscribers/",
          correct_path,
          1
        )
      ]
    end
  end

  # Extract context name from file path
  defp extract_context(file_path) do
    case Regex.run(~r|lib/jarga/([^/]+)/|, file_path) do
      [_, context] -> context
      _ -> "unknown"
    end
  end

  # Create Credo issue
  defp create_issue(issue_meta, trigger, correct_path, line_no) do
    format_issue(
      issue_meta,
      message:
        "Infrastructure file not properly organized.\n" <>
          "  Infrastructure files should be in subdirectories by responsibility.\n" <>
          "  Move to: #{correct_path}",
      trigger: trigger,
      line_no: line_no
    )
  end
end
