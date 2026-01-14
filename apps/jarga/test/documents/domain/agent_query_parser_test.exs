defmodule Jarga.Documents.Domain.AgentQueryParserTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Domain.AgentQueryParser

  describe "parse/1" do
    test "parses valid @j agent_name Question syntax" do
      input = "@j doc-writer How should I structure this?"

      assert {:ok, result} = AgentQueryParser.parse(input)
      assert result.agent_name == "doc-writer"
      assert result.question == "How should I structure this?"
    end

    test "handles multi-word agent names with hyphens" do
      input = "@j my-writer-agent What is the format?"

      assert {:ok, result} = AgentQueryParser.parse(input)
      assert result.agent_name == "my-writer-agent"
      assert result.question == "What is the format?"
    end

    test "handles agent names with underscores" do
      input = "@j my_writer_agent What is this?"

      assert {:ok, result} = AgentQueryParser.parse(input)
      assert result.agent_name == "my_writer_agent"
      assert result.question == "What is this?"
    end

    test "handles questions with special characters" do
      input = "@j agent1 What's the difference? (explain)"

      assert {:ok, result} = AgentQueryParser.parse(input)
      assert result.agent_name == "agent1"
      assert result.question == "What's the difference? (explain)"
    end

    test "handles questions with punctuation" do
      input = "@j agent How do I do this: step 1, step 2?"

      assert {:ok, result} = AgentQueryParser.parse(input)
      assert result.agent_name == "agent"
      assert result.question == "How do I do this: step 1, step 2?"
    end

    test "returns error for invalid format (missing question)" do
      input = "@j agent-name"

      assert {:error, :missing_question} = AgentQueryParser.parse(input)
    end

    test "returns error for invalid format (no agent name)" do
      input = "@j   What is this?"

      assert {:error, :missing_agent_name} = AgentQueryParser.parse(input)
    end

    test "returns error for non-@j text" do
      input = "regular text"

      assert {:error, :invalid_format} = AgentQueryParser.parse(input)
    end

    test "returns error for @j without space" do
      input = "@jagent What is this?"

      assert {:error, :invalid_format} = AgentQueryParser.parse(input)
    end

    test "handles leading and trailing whitespace" do
      input = "  @j agent Question here?  "

      assert {:ok, result} = AgentQueryParser.parse(input)
      assert result.agent_name == "agent"
      assert result.question == "Question here?"
    end
  end
end
