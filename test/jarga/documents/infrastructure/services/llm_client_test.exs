defmodule Jarga.Documents.Infrastructure.Services.LlmClientTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Infrastructure.Services.LlmClient

  describe "chat/2" do
    @tag :skip
    test "sends messages to OpenRouter and returns response" do
      messages = [
        %{role: "user", content: "Hello, how are you?"}
      ]

      assert {:ok, response} = LlmClient.chat(messages)
      assert is_binary(response)
      assert String.length(response) > 0
    end

    @tag :skip
    test "includes system message when provided" do
      messages = [
        %{role: "system", content: "You are a helpful assistant."},
        %{role: "user", content: "What's 2+2?"}
      ]

      assert {:ok, response} = LlmClient.chat(messages)
      assert String.contains?(response, "4")
    end

    @tag :skip
    test "returns error on invalid API key" do
      messages = [%{role: "user", content: "test"}]

      assert {:error, reason} = LlmClient.chat(messages, api_key: "invalid")
      assert reason =~ "authentication" or reason =~ "invalid"
    end

    @tag :skip
    test "respects model parameter" do
      messages = [%{role: "user", content: "Hi"}]

      assert {:ok, _response} =
               LlmClient.chat(messages, model: "google/gemini-2.0-flash-exp:free")
    end
  end

  describe "chat_stream/2" do
    @tag :skip
    test "streams response chunks" do
      messages = [%{role: "user", content: "Count to 5"}]

      {:ok, pid} = LlmClient.chat_stream(messages, self())

      # Should receive chunks
      assert_receive {:chunk, chunk}, 5000
      assert is_binary(chunk)

      # Should receive done
      assert_receive {:done, _full_response}, 10000

      # Cleanup
      if Process.alive?(pid), do: Process.exit(pid, :normal)
    end
  end
end
