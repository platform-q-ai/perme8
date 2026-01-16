defmodule Jarga.Documents.Domain.AgentQueryParser do
  @moduledoc """
  Parses `@j agent_name Question` syntax for agent queries in documents.

  This is pure domain logic with no external dependencies or side effects.

  ## Syntax Rules

  - Must start with `@j ` (at-j followed by single space)
  - Agent name must be alphanumeric, hyphens, or underscores
  - Agent name must be followed by at least one space
  - Question must be non-empty

  ## Error Cases

  - `:invalid_format` - Text doesn't start with `@j `
  - `:missing_agent_name` - No agent name provided after `@j`
  - `:missing_question` - Agent name provided but no question
  - `:invalid_agent_name` - Agent name contains invalid characters
  """

  # Agent names must start with alphanumeric and can contain hyphens/underscores
  @agent_name_pattern ~r/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/

  # Command pattern: @j + single space + agent_name + space(s) + question
  @command_pattern ~r/^@j\s([a-zA-Z0-9_-]+)\s+(.+)$/

  @doc """
  Parses a text command in the format `@j agent_name Question`.

  Leading and trailing whitespace is automatically trimmed.

  ## Parameters

    - `text` - The text to parse (must be a string)

  ## Returns

    - `{:ok, %{agent_name: string, question: string}}` - Successfully parsed command
    - `{:error, :invalid_format}` - Text doesn't start with `@j `
    - `{:error, :missing_agent_name}` - No agent name provided
    - `{:error, :missing_question}` - Agent name without question
    - `{:error, :invalid_agent_name}` - Agent name contains invalid characters

  ## Examples

      iex> parse("@j doc-writer How should I structure this?")
      {:ok, %{agent_name: "doc-writer", question: "How should I structure this?"}}

      iex> parse("@j my-agent What is the format?")
      {:ok, %{agent_name: "my-agent", question: "What is the format?"}}

      iex> parse("@j agent-name")
      {:error, :missing_question}

      iex> parse("@j   What is this?")
      {:error, :missing_agent_name}

      iex> parse("regular text")
      {:error, :invalid_format}
  """
  @spec parse(String.t()) ::
          {:ok, %{agent_name: String.t(), question: String.t()}} | {:error, atom()}
  def parse(text) when is_binary(text) do
    text
    |> String.trim()
    |> do_parse()
  end

  defp do_parse(text) do
    case Regex.run(@command_pattern, text) do
      [_full_match, agent_name, question] ->
        validate_and_build(agent_name, question)

      nil ->
        # Check if it starts with @j to provide more specific errors
        if String.starts_with?(text, "@j") do
          diagnose_error(text)
        else
          {:error, :invalid_format}
        end
    end
  end

  defp validate_and_build(agent_name, question) do
    agent_name = String.trim(agent_name)
    question = String.trim(question)

    cond do
      agent_name == "" ->
        {:error, :missing_agent_name}

      question == "" ->
        {:error, :missing_question}

      not valid_agent_name?(agent_name) ->
        {:error, :invalid_agent_name}

      true ->
        {:ok, %{agent_name: agent_name, question: question}}
    end
  end

  defp valid_agent_name?(name) do
    Regex.match?(@agent_name_pattern, name)
  end

  defp diagnose_error(text) do
    # Remove "@j" prefix and check what remains
    remainder = String.replace_prefix(text, "@j", "")

    if invalid_prefix?(remainder) do
      {:error, :missing_agent_name}
    else
      check_parts(remainder)
    end
  end

  defp invalid_prefix?(remainder) do
    # "@j" with nothing after it
    # "@j   " (multiple spaces, but no agent name starts immediately after)
    # If it starts with more than one space, no agent name was provided
    String.trim(remainder) == "" or
      String.starts_with?(remainder, "  ")
  end

  defp check_parts(remainder) do
    # Try to extract parts after trimming
    parts = remainder |> String.trim() |> String.split(~r/\s+/, parts: 2)

    case parts do
      [] ->
        {:error, :missing_agent_name}

      [_agent_name] ->
        {:error, :missing_question}

      [agent_name, _question] ->
        if valid_agent_name?(agent_name) do
          {:error, :invalid_format}
        else
          {:error, :invalid_agent_name}
        end
    end
  end
end
