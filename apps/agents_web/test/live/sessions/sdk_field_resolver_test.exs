defmodule AgentsWeb.SessionsLive.SdkFieldResolverTest do
  use ExUnit.Case, async: true

  alias AgentsWeb.SessionsLive.SdkFieldResolver

  describe "resolve_message_id/1" do
    test "extracts from 'id' field" do
      assert SdkFieldResolver.resolve_message_id(%{"id" => "msg-1"}) == "msg-1"
    end

    test "extracts from 'messageID' field" do
      assert SdkFieldResolver.resolve_message_id(%{"messageID" => "msg-1"}) == "msg-1"
    end

    test "extracts from 'messageId' field" do
      assert SdkFieldResolver.resolve_message_id(%{"messageId" => "msg-1"}) == "msg-1"
    end

    test "prefers 'messageID' over 'id' (id may be a part ID)" do
      assert SdkFieldResolver.resolve_message_id(%{"id" => "id-1", "messageID" => "mid-1"}) ==
               "mid-1"
    end

    test "returns nil when no recognized field is present" do
      assert SdkFieldResolver.resolve_message_id(%{"other" => "value"}) == nil
      assert SdkFieldResolver.resolve_message_id(%{}) == nil
    end
  end

  describe "resolve_correlation_key/1" do
    test "extracts from 'correlationKey' field" do
      assert SdkFieldResolver.resolve_correlation_key(%{"correlationKey" => "key-1"}) == "key-1"
    end

    test "extracts from 'correlation_key' field" do
      assert SdkFieldResolver.resolve_correlation_key(%{"correlation_key" => "key-1"}) == "key-1"
    end

    test "extracts from 'correlationID' field" do
      assert SdkFieldResolver.resolve_correlation_key(%{"correlationID" => "key-1"}) == "key-1"
    end

    test "prefers 'correlationKey' over 'correlation_key'" do
      assert SdkFieldResolver.resolve_correlation_key(%{
               "correlationKey" => "ck-1",
               "correlation_key" => "ck-2"
             }) == "ck-1"
    end

    test "returns nil when no recognized field is present" do
      assert SdkFieldResolver.resolve_correlation_key(%{"other" => "value"}) == nil
      assert SdkFieldResolver.resolve_correlation_key(%{}) == nil
    end
  end

  describe "resolve_tool_call_id/1" do
    test "extracts from 'id' field" do
      assert SdkFieldResolver.resolve_tool_call_id(%{"id" => "tc-1"}) == "tc-1"
    end

    test "extracts from 'toolCallID' field" do
      assert SdkFieldResolver.resolve_tool_call_id(%{"toolCallID" => "tc-1"}) == "tc-1"
    end

    test "extracts from 'toolCallId' field" do
      assert SdkFieldResolver.resolve_tool_call_id(%{"toolCallId" => "tc-1"}) == "tc-1"
    end

    test "extracts from 'callID' field" do
      assert SdkFieldResolver.resolve_tool_call_id(%{"callID" => "tc-1"}) == "tc-1"
    end

    test "prefers 'id' over variant fields" do
      assert SdkFieldResolver.resolve_tool_call_id(%{"id" => "id-1", "callID" => "cid-1"}) ==
               "id-1"
    end

    test "returns nil when no recognized field is present" do
      assert SdkFieldResolver.resolve_tool_call_id(%{}) == nil
    end
  end

  describe "resolve_model_id/1" do
    test "extracts from 'modelID' field" do
      assert SdkFieldResolver.resolve_model_id(%{"modelID" => "gpt-4"}) == "gpt-4"
    end

    test "extracts from 'modelId' field" do
      assert SdkFieldResolver.resolve_model_id(%{"modelId" => "gpt-4"}) == "gpt-4"
    end

    test "extracts from 'model_id' field" do
      assert SdkFieldResolver.resolve_model_id(%{"model_id" => "gpt-4"}) == "gpt-4"
    end

    test "returns nil when no recognized field is present" do
      assert SdkFieldResolver.resolve_model_id(%{}) == nil
    end
  end
end
