defmodule Credo.Check.Custom.Architecture.ServicesInCorrectLayer do
  @moduledoc """
  Ensures service modules are in the correct layer based on their responsibility.

  This check enforces Clean Architecture by distinguishing:
  - **Application services** (orchestration, mockable deps) → `application/services/`
  - **Infrastructure notifiers** (actual I/O: PubSub, email) → `infrastructure/notifiers/`

  ## Rules

  1. Files named `*_service.ex` → `application/services/`
  2. Files named `*_notifier.ex` → `infrastructure/notifiers/`
  3. Files in `services/` directory at context root → Need to be categorized

  ## Current Violations

  Services at wrong locations:
  - `lib/jarga/documents/services/notification_service.ex` → `application/services/`
  - `lib/jarga/documents/services/pub_sub_notifier.ex` → `infrastructure/notifiers/`

  ## Expected Structure

      lib/jarga/{context}/
      ├── application/
      │   └── services/           # Orchestration, mockable dependencies
      │       └── *_service.ex
      └── infrastructure/
          └── notifiers/          # Actual I/O (PubSub, email)
              └── *_notifier.ex

  ## Configuration

      {Credo.Check.Custom.Architecture.ServicesInCorrectLayer, []}

  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Services and notifiers should be in correct layers based on their responsibilities.

      Application services handle orchestration with mockable dependencies.
      Infrastructure notifiers handle actual I/O (PubSub, email, external APIs).
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    file_path = source_file.filename

    # Only check service and notifier modules
    if is_service_or_notifier?(file_path) do
      check_service_location(file_path, issue_meta)
    else
      []
    end
  end

  # Check if this is a service or notifier module
  defp is_service_or_notifier?(file_path) do
    # Check for services/ directory or files ending in _service.ex or _notifier.ex
    # Exception: legacy naming
    (String.match?(file_path, ~r|lib/jarga/[^/]+/.*services/[^/]+\.ex$|) or
       String.match?(file_path, ~r|lib/jarga/[^/]+/.*_service\.ex$|) or
       String.match?(file_path, ~r|lib/jarga/[^/]+/.*_notifier\.ex$|)) and
      not String.contains?(file_path, "test/") and
      not String.contains?(file_path, "jarga_web") and
      not String.contains?(file_path, "user_notifier.ex")
  end

  # Verify service/notifier is in correct layer
  defp check_service_location(file_path, issue_meta) do
    file_name = Path.basename(file_path)

    cond do
      # ✅ Correct: Services in application/services/
      String.ends_with?(file_name, "_service.ex") and
          String.match?(file_path, ~r|/application/services/[^/]+\.ex$|) ->
        []

      # ✅ Correct: Notifiers in infrastructure/notifiers/
      String.ends_with?(file_name, "_notifier.ex") and
          String.match?(file_path, ~r|/infrastructure/notifiers/[^/]+\.ex$|) ->
        []

      # ❌ VIOLATION: Service not in application/services/
      String.ends_with?(file_name, "_service.ex") ->
        [
          create_issue(
            issue_meta,
            "Application service not in application/services/",
            get_service_correct_path(file_path),
            1
          )
        ]

      # ❌ VIOLATION: Notifier not in infrastructure/notifiers/
      String.ends_with?(file_name, "_notifier.ex") ->
        [
          create_issue(
            issue_meta,
            "Infrastructure notifier not in infrastructure/notifiers/",
            get_notifier_correct_path(file_path),
            1
          )
        ]

      # ❌ VIOLATION: File in root-level services/ directory needs categorization
      # Only flag files in lib/jarga/{context}/services/ (not application/services/ or infrastructure/services/)
      String.match?(file_path, ~r|lib/jarga/[^/]+/services/[^/]+\.ex$|) and
        not String.match?(file_path, ~r|/application/services/|) and
          not String.match?(file_path, ~r|/infrastructure/services/|) ->
        [
          create_ambiguous_issue(
            issue_meta,
            file_path,
            1
          )
        ]

      true ->
        []
    end
  end

  # Generate correct path for services
  defp get_service_correct_path(file_path) do
    file_name = Path.basename(file_path)

    cond do
      # From services/ directory
      String.match?(file_path, ~r|lib/jarga/[^/]+/services/|) ->
        String.replace(file_path, ~r|(lib/jarga/[^/]+)/services/|, "\\1/application/services/")

      # From infrastructure/services/
      String.match?(file_path, ~r|lib/jarga/[^/]+/infrastructure/services/|) ->
        String.replace(
          file_path,
          ~r|(lib/jarga/[^/]+)/infrastructure/services/|,
          "\\1/application/services/"
        )

      true ->
        context = extract_context(file_path)
        "lib/jarga/#{context}/application/services/#{file_name}"
    end
  end

  # Generate correct path for notifiers
  defp get_notifier_correct_path(file_path) do
    file_name = Path.basename(file_path)

    cond do
      # From services/ directory
      String.match?(file_path, ~r|lib/jarga/[^/]+/services/|) ->
        String.replace(
          file_path,
          ~r|(lib/jarga/[^/]+)/services/|,
          "\\1/infrastructure/notifiers/"
        )

      # From infrastructure/services/
      String.match?(file_path, ~r|lib/jarga/[^/]+/infrastructure/services/|) ->
        String.replace(
          file_path,
          ~r|(lib/jarga/[^/]+)/infrastructure/services/|,
          "\\1/infrastructure/notifiers/"
        )

      # From context root
      String.match?(file_path, ~r|lib/jarga/[^/]+/[^/]+_notifier\.ex$|) ->
        String.replace(
          file_path,
          ~r|(lib/jarga/[^/]+)/([^/]+_notifier\.ex)$|,
          "\\1/infrastructure/notifiers/\\2"
        )

      true ->
        context = extract_context(file_path)
        "lib/jarga/#{context}/infrastructure/notifiers/#{file_name}"
    end
  end

  # Extract context name from file path
  defp extract_context(file_path) do
    case Regex.run(~r|lib/jarga/([^/]+)/|, file_path) do
      [_, context] -> context
      _ -> "unknown"
    end
  end

  # Create Credo issue for services/notifiers
  defp create_issue(issue_meta, trigger, correct_path, line_no) do
    format_issue(
      issue_meta,
      message:
        "Service/notifier in wrong layer.\n" <>
          "  Application services (orchestration) → application/services/\n" <>
          "  Infrastructure notifiers (I/O) → infrastructure/notifiers/\n" <>
          "  Move to: #{correct_path}",
      trigger: trigger,
      line_no: line_no
    )
  end

  # Create issue for ambiguous files in services/ directory
  defp create_ambiguous_issue(issue_meta, file_path, line_no) do
    file_name = Path.basename(file_path)
    context = extract_context(file_path)

    service_path = "lib/jarga/#{context}/application/services/#{file_name}"
    notifier_path = "lib/jarga/#{context}/infrastructure/notifiers/#{file_name}"

    format_issue(
      issue_meta,
      message:
        "File in services/ directory needs categorization.\n" <>
          "  If orchestration/mockable: Move to #{service_path}\n" <>
          "  If I/O (PubSub/email): Rename to *_notifier.ex and move to #{notifier_path}",
      trigger: "Ambiguous service file location",
      line_no: line_no
    )
  end
end
