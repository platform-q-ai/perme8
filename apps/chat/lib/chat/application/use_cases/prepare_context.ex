defmodule Chat.Application.UseCases.PrepareContext do
  @moduledoc """
  Prepares chat context from a context map.
  """

  @default_max_content_chars 3000

  def execute(context_map, opts \\ []) do
    max_chars = Keyword.get(opts, :max_content_chars, @default_max_content_chars)

    context = %{
      current_user: get_nested(context_map, [:current_user, :email]),
      current_workspace: get_nested(context_map, [:current_workspace, :name]),
      current_project: get_nested(context_map, [:current_project, :name]),
      document_title: context_map[:document_title],
      document_content: extract_document_content(context_map, max_chars),
      document_info: extract_document_info(context_map)
    }

    {:ok, context}
  end

  def build_system_message_with_agent(agent, context) do
    if agent && has_custom_prompt?(agent) do
      build_combined_message(agent.system_prompt, context)
    else
      build_system_message(context)
    end
  end

  def build_system_message(context) do
    context_parts =
      []
      |> maybe_add_workspace(context)
      |> maybe_add_project(context)
      |> maybe_add_document_title(context)
      |> maybe_add_document_content(context)

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
          You are a helpful assistant for Perme8, a project management application.

          Current context:
          #{context_text}

          Answer questions based on the current document context. Be concise and helpful.
          """
        }
      end

    {:ok, message}
  end

  defp extract_document_content(context_map, max_chars) do
    case get_nested(context_map, [:note, :note_content]) do
      content when is_binary(content) and content != "" -> String.slice(content, 0, max_chars)
      _ -> nil
    end
  end

  defp extract_document_info(context_map) do
    workspace_slug = get_nested(context_map, [:current_workspace, :slug])
    document_slug = get_nested(context_map, [:document, :slug])
    document_title = context_map[:document_title]

    document_url =
      if workspace_slug && document_slug do
        "/app/workspaces/#{workspace_slug}/documents/#{document_slug}"
      else
        nil
      end

    if document_url && document_title do
      %{document_title: document_title, document_url: document_url}
    else
      nil
    end
  end

  defp get_nested(data, [key]) when is_map(data), do: Map.get(data, key)

  defp get_nested(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> nil
      value when is_map(value) -> get_nested(value, rest)
      _ -> nil
    end
  end

  defp get_nested(_, _), do: nil

  defp has_custom_prompt?(agent),
    do: agent.system_prompt && String.trim(agent.system_prompt) != ""

  defp build_combined_message(custom_prompt, context) do
    context_parts =
      []
      |> maybe_add_workspace(context)
      |> maybe_add_project(context)
      |> maybe_add_document_title(context)
      |> maybe_add_document_content(context)

    message =
      if Enum.empty?(context_parts) do
        %{role: "system", content: custom_prompt}
      else
        context_text = Enum.join(context_parts, "\n")

        %{
          role: "system",
          content: """
          #{custom_prompt}

          Current context:
          #{context_text}
          """
        }
      end

    {:ok, message}
  end

  defp maybe_add_workspace(parts, context) do
    if context[:current_workspace],
      do: parts ++ ["You are viewing workspace: #{context.current_workspace}"],
      else: parts
  end

  defp maybe_add_project(parts, context) do
    if context[:current_project],
      do: parts ++ ["You are viewing project: #{context.current_project}"],
      else: parts
  end

  defp maybe_add_document_title(parts, context) do
    if context[:document_title],
      do: parts ++ ["Document title: #{context.document_title}"],
      else: parts
  end

  defp maybe_add_document_content(parts, context) do
    if context[:document_content],
      do: parts ++ ["Document content:\n#{context.document_content}"],
      else: parts
  end
end
