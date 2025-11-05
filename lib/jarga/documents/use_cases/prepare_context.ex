defmodule Jarga.Documents.UseCases.PrepareContext do
  @moduledoc """
  Prepares chat context from LiveView assigns.

  This use case extracts relevant information from the current page (workspace,
  project, page content) and formats it for inclusion in LLM prompts.

  ## Responsibilities
  - Extract user and workspace context
  - Extract page content with truncation
  - Build page URLs for citations
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
  - `page_title` - Current page title
  - `page_content` - Page markdown content (truncated)
  - `page_info` - Page metadata for citations (%{page_title, page_url})
  """
  def execute(assigns) do
    context = %{
      current_user: get_nested(assigns, [:current_user, :email]),
      current_workspace: get_nested(assigns, [:current_workspace, :name]),
      current_project: get_nested(assigns, [:current_project, :name]),
      page_title: assigns[:page_title],
      page_content: extract_page_content(assigns),
      page_info: extract_page_info(assigns)
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
      if context[:page_title] do
        context_parts ++ ["Page title: #{context.page_title}"]
      else
        context_parts
      end

    context_parts =
      if context[:page_content] do
        context_parts ++ ["Page content:\n#{context.page_content}"]
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

          Answer questions based on the current page context. Be concise and helpful.
          """
        }
      end

    {:ok, message}
  end

  # Private functions

  defp extract_page_content(assigns) do
    # Check if we have a note (page content)
    case get_nested(assigns, [:note, :note_content]) do
      %{"markdown" => markdown} when is_binary(markdown) and markdown != "" ->
        # Get max chars from config, defaulting to 3000
        max_chars = Application.get_env(:jarga, :chat_context)[:max_content_chars] || 3000
        String.slice(markdown, 0, max_chars)

      _ ->
        nil
    end
  end

  defp extract_page_info(assigns) do
    # Extract page metadata for source citations
    workspace_slug = get_nested(assigns, [:current_workspace, :slug])
    page_slug = get_nested(assigns, [:page, :slug])
    page_title = assigns[:page_title]

    # Build the page URL if we have the necessary information
    page_url =
      if workspace_slug && page_slug do
        "/app/workspaces/#{workspace_slug}/pages/#{page_slug}"
      else
        nil
      end

    if page_url && page_title do
      %{
        page_title: page_title,
        page_url: page_url
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
