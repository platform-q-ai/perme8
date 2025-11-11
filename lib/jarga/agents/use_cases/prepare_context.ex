defmodule Jarga.Agents.UseCases.PrepareContext do
  @moduledoc """
  Prepares chat context from LiveView assigns.

  This use case extracts relevant information from the current document (workspace,
  project, document content) and formats it for inclusion in LLM prompts.

  ## Responsibilities
  - Extract user and workspace context
  - Extract document content with truncation
  - Build document URLs for citations
  - Format system messages for LLM

  ## Examples

      iex> assigns = %{current_workspace: %{name: "ACME"}}
      iex> PrepareContext.execute(assigns)
      {:ok, %{current_workspace: "ACME", ...}}
  """

  @doc """
  Extracts chat context from LiveView assigns.

  Returns `{:ok, context}` where context is a map containing:
  - `current_user` - User email
  - `current_workspace` - Workspace name
  - `current_project` - Project name
  - `document_title` - Current document title
  - `document_content` - Document markdown content (truncated)
  - `document_info` - Document metadata for citations (%{document_title, document_url})
  """
  def execute(assigns) do
    context = %{
      current_user: get_nested(assigns, [:current_user, :email]),
      current_workspace: get_nested(assigns, [:current_workspace, :name]),
      current_project: get_nested(assigns, [:current_project, :name]),
      document_title: assigns[:page_title],
      document_content: extract_document_content(assigns),
      document_info: extract_document_info(assigns)
    }

    {:ok, context}
  end

  @doc """
  Builds a system message for the LLM from the extracted context.

  Returns `{:ok, message}` where message is a map with `:role` and `:content` keys.
  """
  def build_system_message(context) do
    context_parts = []

    context_parts =
      if context[:current_workspace] do
        context_parts ++ ["You are viewing workspace: #{context.current_workspace}"]
      else
        context_parts
      end

    context_parts =
      if context[:current_project] do
        context_parts ++ ["You are viewing project: #{context.current_project}"]
      else
        context_parts
      end

    context_parts =
      if context[:document_title] do
        context_parts ++ ["Document title: #{context.document_title}"]
      else
        context_parts
      end

    context_parts =
      if context[:document_content] do
        context_parts ++ ["Document content:\n#{context.document_content}"]
      else
        context_parts
      end

    message =
      if Enum.empty?(context_parts) do
        %{
          role: "system",
          content: "You are a helpful assistant. Answer questions based on the context provided."
        }
      else
        context_text = Enum.join(context_parts, "\n")

        %{
          role: "system",
          content: """
          You are a helpful assistant for Jarga, a project management application.

          Current context:
          #{context_text}

          Answer questions based on the current document context. Be concise and helpful.
          """
        }
      end

    {:ok, message}
  end

  # Private functions

  defp extract_document_content(assigns) do
    # Check if we have a note (document content)
    case get_nested(assigns, [:note, :note_content]) do
      %{"markdown" => markdown} when is_binary(markdown) and markdown != "" ->
        # Get max chars from config, defaulting to 3000
        max_chars = Application.get_env(:jarga, :chat_context)[:max_content_chars] || 3000
        String.slice(markdown, 0, max_chars)

      _ ->
        nil
    end
  end

  defp extract_document_info(assigns) do
    # Extract document metadata for source citations
    workspace_slug = get_nested(assigns, [:current_workspace, :slug])
    document_slug = get_nested(assigns, [:page, :slug])
    document_title = assigns[:page_title]

    # Build the document URL if we have the necessary information
    document_url =
      if workspace_slug && document_slug do
        "/app/workspaces/#{workspace_slug}/documents/#{document_slug}"
      else
        nil
      end

    if document_url && document_title do
      %{
        document_title: document_title,
        document_url: document_url
      }
    else
      nil
    end
  end

  # Safely extract nested values from maps/structs
  defp get_nested(data, [key]) when is_map(data) do
    Map.get(data, key)
  end

  defp get_nested(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> nil
      value when is_map(value) -> get_nested(value, rest)
      _ -> nil
    end
  end

  defp get_nested(_, _), do: nil
end
