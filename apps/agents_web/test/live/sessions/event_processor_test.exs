defmodule AgentsWeb.SessionsLive.EventProcessorTest do
  use ExUnit.Case, async: true

  alias AgentsWeb.SessionsLive.EventProcessor

  # Build a minimal socket-like map with the assigns process_event expects.
  defp base_assigns do
    %{
      session_title: nil,
      session_model: nil,
      session_tokens: nil,
      session_cost: nil,
      session_summary: nil,
      output_parts: [],
      pending_question: nil,
      confirmed_user_messages: [],
      optimistic_user_messages: [],
      user_message_ids: MapSet.new()
    }
  end

  # process_event/2 takes an event map and a socket,
  # so we build a fake socket struct with __changed__ tracking.
  defp build_socket(assigns_override \\ %{}) do
    assigns =
      base_assigns()
      |> Map.merge(assigns_override)
      |> Map.put(:__changed__, %{})

    %Phoenix.LiveView.Socket{assigns: assigns}
  end

  describe "process_event/2 — session.updated" do
    test "sets session_title from info" do
      socket = build_socket()

      event = %{
        "type" => "session.updated",
        "properties" => %{"info" => %{"title" => "Fix login bug", "summary" => "Auth fix"}}
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.session_title == "Fix login bug"
      assert result.assigns.session_summary == "Auth fix"
    end

    test "does not overwrite existing title with nil" do
      socket = build_socket(%{session_title: "Existing"})

      event = %{
        "type" => "session.updated",
        "properties" => %{"info" => %{"title" => nil}}
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.session_title == "Existing"
    end
  end

  describe "process_event/2 — message.updated (assistant)" do
    test "sets model and tokens from assistant message" do
      socket = build_socket()

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{
            "role" => "assistant",
            "modelID" => "gpt-5.3-codex",
            "tokens" => %{"input" => 5200, "output" => 150},
            "cost" => 0.05
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.session_model == "gpt-5.3-codex"
      assert result.assigns.session_tokens == %{"input" => 5200, "output" => 150}
      assert result.assigns.session_cost == 0.05
    end
  end

  describe "process_event/2 — message.part.updated (text)" do
    test "adds new text part to output_parts" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"id" => "part-1", "type" => "text", "text" => "Hello world"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert [{:text, "part-1", "Hello world", :streaming}] = result.assigns.output_parts
    end

    test "updates existing text part by ID" do
      socket = build_socket(%{output_parts: [{:text, "part-1", "Hello", :streaming}]})

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"id" => "part-1", "type" => "text", "text" => "Hello world"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert [{:text, "part-1", "Hello world", :streaming}] = result.assigns.output_parts
    end

    test "ignores empty text" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"id" => "part-1", "type" => "text", "text" => ""}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.output_parts == []
    end

    test "converts user message parts into chat user timeline entries" do
      socket = build_socket(%{user_message_ids: MapSet.new(["msg-1"])})

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "id" => "part-1",
            "type" => "text",
            "text" => "User typed this",
            "messageID" => "msg-1"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.output_parts == [{:user, "msg-1", "User typed this"}]
    end

    test "supports lower-camel messageId for user parts" do
      socket =
        build_socket(%{
          user_message_ids: MapSet.new(["msg-2"]),
          optimistic_user_messages: ["Queued follow-up"]
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "id" => "part-2",
            "type" => "text",
            "text" => "Queued follow-up",
            "messageId" => "msg-2"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)

      assert result.assigns.output_parts == [{:user, "msg-2", "Queued follow-up"}]
      assert result.assigns.optimistic_user_messages == []
    end
  end

  describe "maybe_load_cached_output/2" do
    test "restores persisted user follow-up messages from cached output" do
      output =
        Jason.encode!([
          %{"type" => "text", "id" => "a-1", "text" => "Assistant output"},
          %{"type" => "user", "id" => "user-msg-1", "text" => "Applied follow-up"}
        ])

      socket = build_socket()

      result = EventProcessor.maybe_load_cached_output(socket, %{output: output})

      assert result.assigns.output_parts == [
               {:text, "a-1", "Assistant output", :frozen},
               {:user, "user-msg-1", "Applied follow-up"}
             ]
    end
  end

  describe "process_event/2 — question.asked" do
    test "sets pending_question from event" do
      socket = build_socket()

      event = %{
        "type" => "question.asked",
        "properties" => %{
          "id" => "req-1",
          "sessionID" => "sess-1",
          "questions" => [
            %{
              "header" => "Choose",
              "question" => "Pick one",
              "options" => [%{"label" => "A"}, %{"label" => "B"}]
            }
          ]
        }
      }

      result = EventProcessor.process_event(event, socket)
      pending = result.assigns.pending_question
      assert pending.request_id == "req-1"
      assert pending.session_id == "sess-1"
      assert length(pending.questions) == 1
      assert pending.selected == [[]]
      assert pending.rejected == false
    end

    test "ignores empty questions list" do
      socket = build_socket()

      event = %{
        "type" => "question.asked",
        "properties" => %{"id" => "req-1", "questions" => []}
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.pending_question == nil
    end
  end

  describe "process_event/2 — question.replied" do
    test "clears pending_question" do
      socket =
        build_socket(%{
          pending_question: %{request_id: "req-1", questions: [], selected: [], rejected: false}
        })

      event = %{"type" => "question.replied"}

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.pending_question == nil
    end
  end

  describe "process_event/2 — question.rejected" do
    test "marks pending_question as rejected" do
      socket =
        build_socket(%{
          pending_question: %{
            request_id: "req-1",
            questions: [],
            selected: [],
            custom_text: [],
            rejected: false
          }
        })

      event = %{"type" => "question.rejected"}

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.pending_question.rejected == true
    end

    test "returns unchanged socket when no pending_question" do
      socket = build_socket(%{pending_question: nil})
      event = %{"type" => "question.rejected"}

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.pending_question == nil
    end
  end

  describe "process_event/2 — message.updated (user) queued message cleanup" do
    test "removes matching queued message by content when user message.updated arrives" do
      socket =
        build_socket(%{
          queued_messages: [
            %{id: "q-1", content: "fix the bug", queued_at: ~U[2026-03-01 00:00:00Z]}
          ]
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{"role" => "user", "id" => "msg-1", "content" => "fix the bug"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.queued_messages == []
    end

    test "removes only the first matching queued message (preserves later duplicates)" do
      socket =
        build_socket(%{
          queued_messages: [
            %{id: "q-1", content: "fix the bug", queued_at: ~U[2026-03-01 00:00:00Z]},
            %{id: "q-2", content: "fix the bug", queued_at: ~U[2026-03-01 00:01:00Z]}
          ]
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{"role" => "user", "id" => "msg-1", "content" => "fix the bug"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert [%{id: "q-2"}] = result.assigns.queued_messages
    end

    test "leaves queued_messages unchanged when no content match" do
      socket =
        build_socket(%{
          queued_messages: [
            %{id: "q-1", content: "fix the bug", queued_at: ~U[2026-03-01 00:00:00Z]}
          ]
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{"role" => "user", "id" => "msg-1", "content" => "something else"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert [%{id: "q-1"}] = result.assigns.queued_messages
    end

    test "leaves queued_messages unchanged when queued_messages is empty" do
      socket = build_socket(%{queued_messages: []})

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{"role" => "user", "id" => "msg-1", "content" => "fix the bug"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.queued_messages == []
    end

    test "handles queued_messages assign not present (backward compat)" do
      # base_assigns does not include queued_messages
      socket = build_socket()

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{"role" => "user", "id" => "msg-1", "content" => "fix the bug"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      # Should not crash; user_message_ids still tracked
      assert MapSet.member?(result.assigns.user_message_ids, "msg-1")
    end

    test "matches content from parts array format" do
      socket =
        build_socket(%{
          queued_messages: [
            %{id: "q-1", content: "fix the bug", queued_at: ~U[2026-03-01 00:00:00Z]}
          ]
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{
            "role" => "user",
            "id" => "msg-1",
            "parts" => [%{"text" => "fix the bug"}]
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.queued_messages == []
    end
  end

  describe "decode_cached_output/1" do
    test "decodes JSON array of text parts" do
      json =
        Jason.encode!([
          %{"type" => "text", "id" => "t-1", "text" => "Hello"},
          %{"type" => "text", "id" => "t-2", "text" => "World"}
        ])

      parts = EventProcessor.decode_cached_output(json)

      assert [
               {:text, "t-1", "Hello", :frozen},
               {:text, "t-2", "World", :frozen}
             ] = parts
    end

    test "decodes JSON array with tool parts" do
      json =
        Jason.encode!([
          %{
            "type" => "tool",
            "id" => "tool-1",
            "name" => "bash",
            "status" => "done",
            "input" => "ls"
          }
        ])

      parts = EventProcessor.decode_cached_output(json)
      assert [{:tool, "tool-1", "bash", :done, detail}] = parts
      assert detail.input == "ls"
    end

    test "falls back to plain text for non-JSON output" do
      parts = EventProcessor.decode_cached_output("just some plain text")
      assert [{:text, "cached-0", "just some plain text", :frozen}] = parts
    end
  end

  describe "has_streaming_parts?/1" do
    test "returns true when there are streaming text parts" do
      assert EventProcessor.has_streaming_parts?([{:text, "t-1", "hi", :streaming}])
    end

    test "returns true when there are running tool parts" do
      assert EventProcessor.has_streaming_parts?([
               {:tool, "t-1", "bash", :running, %{}}
             ])
    end

    test "returns false when all parts are frozen/done" do
      refute EventProcessor.has_streaming_parts?([
               {:text, "t-1", "hi", :frozen},
               {:tool, "t-2", "bash", :done, %{}}
             ])
    end

    test "returns false for empty list" do
      refute EventProcessor.has_streaming_parts?([])
    end
  end

  describe "freeze_streaming/1" do
    test "freezes streaming text and reasoning parts" do
      parts = [
        {:text, "t-1", "hello", :streaming},
        {:reasoning, "r-1", "thinking", :streaming},
        {:tool, "tool-1", "bash", :done, %{}}
      ]

      frozen = EventProcessor.freeze_streaming(parts)

      assert [
               {:text, "t-1", "hello", :frozen},
               {:reasoning, "r-1", "thinking", :frozen},
               {:tool, "tool-1", "bash", :done, %{}}
             ] = frozen
    end

    test "leaves already frozen parts unchanged" do
      parts = [{:text, "t-1", "hello", :frozen}]
      assert ^parts = EventProcessor.freeze_streaming(parts)
    end

    test "marks running tool parts as done" do
      parts = [{:tool, "tool-1", "bash", :running, %{input: "ls"}}]

      assert EventProcessor.freeze_streaming(parts) ==
               [{:tool, "tool-1", "bash", :done, %{input: "ls"}}]
    end
  end
end
