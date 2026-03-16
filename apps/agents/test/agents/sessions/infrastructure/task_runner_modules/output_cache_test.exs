defmodule Agents.Sessions.Infrastructure.TaskRunner.OutputCacheTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.TaskRunner.OutputCache

  describe "upsert_part/3" do
    test "appends new part when no match" do
      parts = [%{"id" => "a", "text" => "hello"}]
      result = OutputCache.upsert_part(parts, "b", %{"id" => "b", "text" => "world"})
      assert length(result) == 2
      assert List.last(result)["id"] == "b"
    end

    test "replaces existing part by ID" do
      parts = [%{"id" => "a", "text" => "old"}]
      result = OutputCache.upsert_part(parts, "a", %{"id" => "a", "text" => "new"})
      assert length(result) == 1
      assert hd(result)["text"] == "new"
    end

    test "appends when part_id is nil" do
      parts = [%{"id" => "a"}]
      result = OutputCache.upsert_part(parts, nil, %{"id" => nil, "text" => "hi"})
      assert length(result) == 2
    end
  end

  describe "serialize_parts/1" do
    test "returns nil for empty list" do
      assert OutputCache.serialize_parts([]) == nil
    end

    test "returns JSON string for non-empty list" do
      parts = [%{"type" => "text", "id" => "1", "text" => "hi"}]
      result = OutputCache.serialize_parts(parts)
      assert is_binary(result)
      assert {:ok, ^parts} = Jason.decode(result)
    end
  end

  describe "restore_parts/1" do
    test "returns empty list for nil" do
      assert OutputCache.restore_parts(nil) == []
    end

    test "returns empty list for empty string" do
      assert OutputCache.restore_parts("") == []
    end

    test "decodes JSON array" do
      parts = [%{"type" => "text", "id" => "1", "text" => "hi"}]
      json = Jason.encode!(parts)
      assert OutputCache.restore_parts(json) == parts
    end

    test "wraps plain text as text part" do
      result = OutputCache.restore_parts("some plain output")
      assert [%{"type" => "text", "id" => "cached-0", "text" => "some plain output"}] = result
    end

    test "returns empty list for non-binary/nil" do
      assert OutputCache.restore_parts(123) == []
    end
  end

  describe "put_output_attrs/3" do
    test "adds output when parts exist" do
      parts = [%{"type" => "text", "id" => "1", "text" => "hi"}]
      result = OutputCache.put_output_attrs(%{status: "done"}, parts, "")
      assert Map.has_key?(result, :output)
      assert is_binary(result.output)
    end

    test "falls back to output_text when parts empty" do
      result = OutputCache.put_output_attrs(%{}, [], "some text")
      assert result == %{output: "some text"}
    end

    test "returns attrs unchanged when no output" do
      result = OutputCache.put_output_attrs(%{status: "done"}, [], "")
      assert result == %{status: "done"}
    end
  end

  describe "build_subtask_entry/1" do
    test "builds correct subtask map" do
      part = %{
        "type" => "subtask",
        "messageID" => "msg-1",
        "agent" => "code-agent",
        "description" => "fix bug",
        "prompt" => "Fix the thing"
      }

      {entry, subtask_id} = OutputCache.build_subtask_entry(part)
      assert subtask_id == "subtask-msg-1"
      assert entry["type"] == "subtask"
      assert entry["agent"] == "code-agent"
      assert entry["status"] == "running"
    end

    test "handles missing messageID" do
      part = %{"type" => "subtask"}
      {entry, subtask_id} = OutputCache.build_subtask_entry(part)
      assert subtask_id == nil
      assert entry["agent"] == "unknown"
    end
  end

  describe "mark_subtask_done/2" do
    test "marks matching part as done" do
      parts = [
        %{"id" => "subtask-msg-1", "status" => "running"},
        %{"id" => "text-1", "status" => "running"}
      ]

      result = OutputCache.mark_subtask_done(parts, "subtask-msg-1")
      assert hd(result)["status"] == "done"
      assert List.last(result)["status"] == "running"
    end

    test "returns unchanged when no match" do
      parts = [%{"id" => "other", "status" => "running"}]
      result = OutputCache.mark_subtask_done(parts, "subtask-msg-1")
      assert result == parts
    end

    test "returns unchanged for nil part_id" do
      parts = [%{"id" => "a", "status" => "running"}]
      assert OutputCache.mark_subtask_done(parts, nil) == parts
    end
  end

  describe "build_user_message_entry/1" do
    test "builds user part map" do
      part = %{"text" => "hello", "messageID" => "m1"}
      {entry, part_id} = OutputCache.build_user_message_entry(part)
      assert entry == %{"type" => "user", "id" => "user-m1", "text" => "hello"}
      assert part_id == "user-m1"
    end
  end

  describe "build_queued_user_entry/2" do
    test "builds pending user part with correlation_key" do
      result =
        OutputCache.build_queued_user_entry("fix bug", %{"correlation_key" => "ck-1"})

      assert {entry, pending_id} = result
      assert entry["pending"] == true
      assert entry["type"] == "user"
      assert pending_id == "queued-user-ck-1"
    end

    test "generates unique ID without correlation_key" do
      {entry, pending_id} = OutputCache.build_queued_user_entry("fix bug")
      assert entry["pending"] == true
      assert String.starts_with?(pending_id, "queued-user-")
    end

    test "returns nil for empty messages" do
      assert OutputCache.build_queued_user_entry("") == nil
      assert OutputCache.build_queued_user_entry("   ") == nil
    end

    test "returns nil for non-binary" do
      assert OutputCache.build_queued_user_entry(nil) == nil
    end
  end

  describe "promote_pending_user_part/3" do
    test "replaces matching pending part" do
      parts = [%{"type" => "user", "pending" => true, "text" => "hello"}]
      {result, matched?} = OutputCache.promote_pending_user_part(parts, "hello", "user-1")
      assert matched?
      assert hd(result) == %{"type" => "user", "id" => "user-1", "text" => "hello"}
      refute Map.has_key?(hd(result), "pending")
    end

    test "returns false when no match" do
      parts = [%{"type" => "user", "pending" => true, "text" => "other"}]
      {_result, matched?} = OutputCache.promote_pending_user_part(parts, "hello", "user-1")
      refute matched?
    end
  end

  describe "build_answer_entry/3" do
    test "uses message when provided" do
      {entry, part_id} = OutputCache.build_answer_entry("req-1", "my answer", [])
      assert entry["text"] == "my answer"
      assert part_id == "user-answer-req-1"
    end

    test "formats answers when no message" do
      {entry, _} = OutputCache.build_answer_entry("req-1", nil, [["yes", "maybe"]])
      assert entry["text"] =~ "Answer 1:"
    end

    test "returns nil for blank answer" do
      assert OutputCache.build_answer_entry("req-1", "", []) == nil
    end
  end

  describe "format_answers_for_cache/1" do
    test "joins multi-answer lists" do
      result = OutputCache.format_answers_for_cache([["yes"], ["no"]])
      assert result =~ "Answer 1: yes"
      assert result =~ "Answer 2: no"
    end

    test "returns empty string for non-list" do
      assert OutputCache.format_answers_for_cache(nil) == ""
    end
  end

  describe "build_tool_entry/3" do
    test "merges tool state into entry" do
      part = %{"id" => "t1", "tool" => "file_read"}
      tool_state = %{"status" => "completed", "output" => "content"}
      result = OutputCache.build_tool_entry(part, tool_state, %{})
      assert result["name"] == "file_read"
      assert result["status"] == "done"
      assert result["output"] == "content"
    end

    test "preserves existing fields not in new state" do
      existing = %{"input" => "old_input", "title" => "old_title"}
      part = %{"id" => "t1"}
      tool_state = %{"status" => "completed"}
      result = OutputCache.build_tool_entry(part, tool_state, existing)
      assert result["input"] == "old_input"
      assert result["title"] == "old_title"
    end
  end

  describe "normalize_tool_status/1" do
    test "maps completed to done" do
      assert OutputCache.normalize_tool_status("completed") == "done"
    end

    test "maps error to error" do
      assert OutputCache.normalize_tool_status("error") == "error"
    end

    test "maps other to running" do
      assert OutputCache.normalize_tool_status("pending") == "running"
      assert OutputCache.normalize_tool_status(nil) == "running"
    end
  end

  describe "serialize_error/1" do
    test "passes through strings" do
      assert OutputCache.serialize_error("error msg") == "error msg"
    end

    test "extracts data.message" do
      assert OutputCache.serialize_error(%{"data" => %{"message" => "deep"}}) == "deep"
    end

    test "extracts message" do
      assert OutputCache.serialize_error(%{"message" => "msg"}) == "msg"
    end

    test "JSON encodes other maps" do
      result = OutputCache.serialize_error(%{"code" => 500})
      assert is_binary(result)
    end

    test "inspects other types" do
      result = OutputCache.serialize_error({:error, :timeout})
      assert result == "{:error, :timeout}"
    end
  end
end
