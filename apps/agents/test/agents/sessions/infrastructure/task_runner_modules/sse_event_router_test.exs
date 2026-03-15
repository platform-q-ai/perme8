defmodule Agents.Sessions.Infrastructure.TaskRunner.SseEventRouterTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.TaskRunner.SseEventRouter

  describe "extract_session_id/1" do
    test "extracts from properties.sessionID" do
      event = %{"properties" => %{"sessionID" => "s1"}}
      assert SseEventRouter.extract_session_id(event) == "s1"
    end

    test "extracts from properties.session_id" do
      event = %{"properties" => %{"session_id" => "s2"}}
      assert SseEventRouter.extract_session_id(event) == "s2"
    end

    test "extracts from properties.part.sessionID" do
      event = %{"properties" => %{"part" => %{"sessionID" => "s3"}}}
      assert SseEventRouter.extract_session_id(event) == "s3"
    end

    test "returns nil for missing properties" do
      assert SseEventRouter.extract_session_id(%{}) == nil
      assert SseEventRouter.extract_session_id(nil) == nil
    end
  end

  describe "track_subtask_message_id/3" do
    test "adds message ID to subtask_message_ids and registers child session" do
      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "subtask",
            "messageID" => "msg-1",
            "sessionID" => "child-1"
          }
        }
      }

      {sids, csids} =
        SseEventRouter.track_subtask_message_id(event, MapSet.new(), %{})

      assert MapSet.member?(sids, "msg-1")
      assert csids["child-1"] == "subtask-msg-1"
    end

    test "is a no-op for non-subtask events" do
      event = %{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"type" => "text"}}
      }

      {sids, csids} =
        SseEventRouter.track_subtask_message_id(event, MapSet.new(), %{})

      assert MapSet.size(sids) == 0
      assert csids == %{}
    end
  end

  describe "subtask_part?/1" do
    test "returns true for subtask type" do
      event = %{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"type" => "subtask"}}
      }

      assert SseEventRouter.subtask_part?(event)
    end

    test "returns false for other types" do
      event = %{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"type" => "text"}}
      }

      refute SseEventRouter.subtask_part?(event)
    end
  end

  describe "track_user_message_id/3" do
    test "adds user message ID" do
      event = %{
        "type" => "message.updated",
        "properties" => %{"info" => %{"role" => "user", "id" => "u1"}}
      }

      result =
        SseEventRouter.track_user_message_id(event, MapSet.new(), MapSet.new())

      assert MapSet.member?(result, "u1")
    end

    test "skips subtask messages" do
      event = %{
        "type" => "message.updated",
        "properties" => %{"info" => %{"role" => "user", "id" => "u1"}}
      }

      subtask_ids = MapSet.new(["u1"])

      result =
        SseEventRouter.track_user_message_id(event, MapSet.new(), subtask_ids)

      refute MapSet.member?(result, "u1")
    end

    test "is a no-op for non-user messages" do
      event = %{"type" => "other"}

      result =
        SseEventRouter.track_user_message_id(event, MapSet.new(), MapSet.new())

      assert MapSet.size(result) == 0
    end
  end

  describe "user_message_part?/3" do
    test "returns true for parts matching user message IDs (messageID)" do
      event = %{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"messageID" => "u1"}}
      }

      assert SseEventRouter.user_message_part?(event, MapSet.new(["u1"]), MapSet.new())
    end

    test "returns true for parts matching user message IDs (messageId)" do
      event = %{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"messageId" => "u1"}}
      }

      assert SseEventRouter.user_message_part?(event, MapSet.new(["u1"]), MapSet.new())
    end

    test "returns false for subtask message parts" do
      event = %{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"messageID" => "u1"}}
      }

      refute SseEventRouter.user_message_part?(
               event,
               MapSet.new(["u1"]),
               MapSet.new(["u1"])
             )
    end

    test "returns false for non-matching parts" do
      event = %{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"messageID" => "other"}}
      }

      refute SseEventRouter.user_message_part?(event, MapSet.new(["u1"]), MapSet.new())
    end
  end
end
