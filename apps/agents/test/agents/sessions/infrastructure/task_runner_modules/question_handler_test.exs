defmodule Agents.Sessions.Infrastructure.TaskRunner.QuestionHandlerTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.TaskRunner.QuestionHandler

  describe "extract_tool_name/1" do
    test "returns tool when it's a string" do
      assert QuestionHandler.extract_tool_name(%{"tool" => "file_read"}) == "file_read"
    end

    test "returns permission when tool is not a string" do
      assert QuestionHandler.extract_tool_name(%{"tool" => %{}, "permission" => "execute"}) ==
               "execute"
    end

    test "returns name as fallback" do
      assert QuestionHandler.extract_tool_name(%{"name" => "bash"}) == "bash"
    end

    test "returns unknown for missing/non-string fields" do
      assert QuestionHandler.extract_tool_name(%{}) == "unknown"
      assert QuestionHandler.extract_tool_name(nil) == "unknown"
    end
  end

  describe "valid_session_summary?/1" do
    test "returns true for valid summary" do
      assert QuestionHandler.valid_session_summary?(%{
               "files" => 3,
               "additions" => 10,
               "deletions" => 5
             })
    end

    test "returns false for extra keys" do
      refute QuestionHandler.valid_session_summary?(%{
               "files" => 3,
               "additions" => 10,
               "deletions" => 5,
               "extra" => true
             })
    end

    test "returns false for non-integer values" do
      refute QuestionHandler.valid_session_summary?(%{
               "files" => "3",
               "additions" => 10,
               "deletions" => 5
             })
    end

    test "returns false for missing keys" do
      refute QuestionHandler.valid_session_summary?(%{"files" => 3})
    end

    test "returns false for non-map" do
      refute QuestionHandler.valid_session_summary?(nil)
    end
  end

  describe "sanitize_fresh_start_reason/1" do
    test "sanitizes docker prepare failure" do
      reason = {:docker_prepare_fresh_start_failed, 1, "raw docker output"}

      assert QuestionHandler.sanitize_fresh_start_reason(reason) ==
               "container repo sync failed (exit 1)"
    end

    test "sanitizes auth refresh failure" do
      reason = {:auth_refresh_failed, :github}
      assert QuestionHandler.sanitize_fresh_start_reason(reason) == "auth refresh failed"
    end

    test "returns generic message for unknown errors" do
      assert QuestionHandler.sanitize_fresh_start_reason(:something_else) ==
               "internal preparation error"
    end
  end
end
