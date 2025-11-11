defmodule Jarga.Agents.UseCases.CreateSession do
  @moduledoc """
  Creates a new chat session.

  This use case handles the creation of new chat sessions, optionally
  generating a title from the first message if not provided.

  ## Responsibilities
  - Create chat session record
  - Auto-generate title from first message if needed
  - Validate required fields

  ## Examples

      iex> CreateSession.execute(%{user_id: user.id})
      {:ok, %ChatSession{}}

      iex> CreateSession.execute(%{user_id: user.id, title: "My Chat"})
      {:ok, %ChatSession{title: "My Chat"}}

      iex> CreateSession.execute(%{user_id: user.id, first_message: "Hello?"})
      {:ok, %ChatSession{title: "Hello?"}}
  """

  alias Jarga.Repo
  alias Jarga.Agents.ChatSession

  @max_auto_title_length 50

  @doc """
  Creates a new chat session.

  ## Parameters
    - attrs: Map with the following keys:
      - user_id: (required) ID of the user creating the session
      - workspace_id: (optional) ID of the workspace
      - project_id: (optional) ID of the project
      - title: (optional) Title of the session
      - first_message: (optional) First message content for auto-title generation

  Returns `{:ok, session}` if successful, or `{:error, changeset}` if validation fails.
  """
  def execute(attrs) do
    attrs = maybe_generate_title(attrs)

    %ChatSession{}
    |> ChatSession.changeset(attrs)
    |> Repo.insert()
  end

  defp maybe_generate_title(%{title: title} = attrs) when not is_nil(title) do
    # Title already provided, don't generate
    attrs
  end

  defp maybe_generate_title(%{first_message: message} = attrs)
       when is_binary(message) and message != "" do
    title = generate_title_from_message(message)
    Map.put(attrs, :title, title)
  end

  defp maybe_generate_title(attrs), do: attrs

  defp generate_title_from_message(message) do
    # Trim and take first line
    title = message |> String.trim() |> String.split("\n") |> List.first()

    if String.length(title) > @max_auto_title_length do
      String.slice(title, 0, @max_auto_title_length - 3) <> "..."
    else
      title
    end
  end
end
