defmodule Mix.Tasks.StepLinter.Rules.FileTooLong do
  @moduledoc """
  Detects step definition files that are too long.

  Large step definition files are difficult to maintain and indicate that
  the file is handling too many concerns. Split into smaller, focused files
  organized by logical groupings.

  ## Why This Matters

  - **Maintainability**: Large files are harder to navigate and understand
  - **Organization**: Steps should be grouped by domain/feature area
  - **Reusability**: Smaller files make it easier to find and reuse steps
  - **Code review**: Smaller files are easier to review

  ## File Naming Convention

  Step definition files are organized by **domain** (folder) and **verb/action** (file):

  ```
  test/features/step_definitions/
  ├── {domain}/
  │   ├── setup.exs        # Background/Given steps for test setup
  │   ├── create.exs       # Steps for creating entities
  │   ├── update.exs       # Steps for updating entities
  │   ├── delete.exs       # Steps for deleting entities
  │   ├── query.exs        # Steps for reading/listing entities
  │   ├── verify.exs       # Then steps for assertions/verification
  │   ├── authorize.exs    # Steps for permission/access checks
  │   └── {feature}.exs    # Specialist feature (e.g., collaborate.exs, streaming.exs)
  ```

  ### Standard Verb Files

  | File | Purpose | Step Types |
  |------|---------|------------|
  | `setup.exs` | Test fixtures, background setup | Given steps |
  | `create.exs` | Creating new entities | When steps |
  | `update.exs` | Modifying existing entities | When steps |
  | `delete.exs` | Removing entities | When steps |
  | `query.exs` | Reading, listing, searching | When/Then steps |
  | `verify.exs` | Assertions, validations | Then steps |
  | `authorize.exs` | Permission checks, access control | Given/Then steps |

  ### Specialist Feature Files

  For domain-specific features that don't fit standard verbs:

  | Domain | Specialist File | Purpose |
  |--------|-----------------|---------|
  | `documents/` | `collaborate.exs` | Real-time collaboration steps |
  | `documents/` | `components.exs` | Document component steps |
  | `chat/` | `send.exs` | Message sending steps |
  | `chat/` | `receive.exs` | Response/streaming steps |
  | `chat/` | `sessions.exs` | Chat session management |
  | `chat/` | `select.exs` | Agent selection steps |
  | `chat/` | `navigate.exs` | Panel UI navigation |
  | `chat/` | `browser.exs` | Wallaby browser tests (@javascript) |
  | `chat/` | `editor.exs` | In-document chat editor |
  | `workspaces/` | `members.exs` | Member management steps |
  | `agents/` | `assign.exs` | Agent assignment to workspaces |

  ## How to Split a Large File

  ### Example: Splitting `chat/sessions.exs` (1500+ lines)

  **Before:**
  ```
  chat/sessions.exs (1500 lines - too large!)
  ```

  **After:**
  ```
  chat/
  ├── sessions.exs          # Core session CRUD (create, load, list)
  ├── sessions_history.exs  # Conversation history, pagination
  └── sessions_verify.exs   # Session verification/assertion steps
  ```

  Or if steps are verb-based, move to appropriate files:
  ```
  chat/
  ├── setup.exs    # Move session fixture/setup steps here
  ├── query.exs    # Move session listing/loading steps here
  ├── delete.exs   # Move session deletion steps here
  └── verify.exs   # Move session verification steps here
  ```

  ## Guidelines for Splitting

  1. **Prefer existing verb files** - Move steps to setup.exs, create.exs, etc. when possible
  2. **Create specialist files** for domain-specific features that don't fit verbs
  3. **Keep related Given/When/Then steps together** in the same file
  4. **Use descriptive names** - `sessions_history.exs` not `sessions2.exs`
  5. **Aim for 150-450 lines per file**
  6. **Run tests after each split** to verify nothing broke
  """
  use Boundary, classify_to: JargaApp

  @behaviour Mix.Tasks.StepLinter.Rule

  @max_lines 450

  @impl true
  def name, do: "file_too_long"

  @impl true
  def description do
    "Detects step files over #{@max_lines} lines - split into smaller logical groupings"
  end

  @doc """
  This rule checks at the file level, not individual steps.
  Returns issues based on total file line count.
  """
  @impl true
  def check(%{file_line_count: line_count, file: file}) when is_integer(line_count) do
    if line_count > @max_lines do
      suggestion = suggest_split(file, line_count)

      [
        %{
          rule: name(),
          message: "File is #{line_count} lines (max: #{@max_lines}). #{suggestion}",
          severity: :warning,
          line: 1,
          details: %{
            line_count: line_count,
            max_lines: @max_lines,
            file: file
          }
        }
      ]
    else
      []
    end
  end

  # Fallback for when file_line_count is not provided (called per-step)
  def check(_step_definition), do: []

  # Generate context-aware split suggestions based on file name
  defp suggest_split(file, line_count) do
    basename = Path.basename(file, ".exs")
    dirname = file |> Path.dirname() |> Path.basename()

    get_suggestion_for_file(basename, dirname, line_count)
  end

  defp get_suggestion_for_file("sessions", "chat", _line_count) do
    "Split into: sessions.exs (core CRUD), sessions_history.exs (history/pagination), " <>
      "or move steps to setup.exs, query.exs, delete.exs, verify.exs by verb."
  end

  defp get_suggestion_for_file("navigate", "chat", _line_count) do
    "Split into: navigate.exs (panel navigation), ui.exs (UI state), " <>
      "markdown.exs (rendering), or move verification steps to verify.exs."
  end

  defp get_suggestion_for_file("receive", "chat", _line_count) do
    "Split into: receive.exs (core receiving), streaming.exs (real-time streaming), " <>
      "errors.exs (error handling), or move verification steps to verify.exs."
  end

  defp get_suggestion_for_file("send", "chat", _line_count) do
    "Split into: send.exs (message sending), input.exs (input handling), " <>
      "validation.exs (message validation)."
  end

  defp get_suggestion_for_file("setup", _dirname, _line_count) do
    "Split setup steps by entity type or move shared fixtures to a helpers module. " <>
      "Keep only Given steps for test setup."
  end

  defp get_suggestion_for_file("verify", _dirname, _line_count) do
    "Split verification steps by what's being verified (e.g., verify_ui.exs, verify_data.exs). " <>
      "Keep only Then/assertion steps."
  end

  defp get_suggestion_for_file(basename, _dirname, _line_count)
       when basename in ["create", "update", "delete"] do
    "Extract helper functions to reduce step size, or split by entity subtype."
  end

  defp get_suggestion_for_file(_basename, _dirname, line_count) when line_count > 1000 do
    "File is very large. Split by verb (setup, create, query, verify) or by feature area. " <>
      "See @moduledoc in FileTooLong rule for naming conventions."
  end

  defp get_suggestion_for_file(_basename, _dirname, _line_count) do
    "Split by verb (setup.exs, create.exs, query.exs, verify.exs) or specialist feature. " <>
      "See @moduledoc in FileTooLong rule for naming conventions."
  end
end
