defmodule AgentsWeb.DashboardLive.EventProcessorTest do
  use ExUnit.Case, async: true

  alias AgentsWeb.DashboardLive.EventProcessor

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
      user_message_ids: MapSet.new(),
      subtask_message_ids: MapSet.new()
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

  describe "process_event/2 — message.part.updated (tool)" do
    test "ignores empty running tool parts with no identity/details" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "tool",
            "state" => %{"status" => "running"}
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.output_parts == []
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

    test "ignores empty cached tool entries" do
      output = Jason.encode!([%{"type" => "tool", "name" => "", "status" => "running"}])

      socket = build_socket()
      result = EventProcessor.maybe_load_cached_output(socket, %{output: output})

      assert result.assigns.output_parts == []
    end
  end

  describe "maybe_load_pending_question/2" do
    test "does not resurrect question card when user already replied in output" do
      question_tool =
        {:tool, "tool-q-1", "questions", :done,
         %{input: %{"questions" => [%{"header" => "H", "question" => "Q", "options" => []}]}}}

      socket = build_socket(%{output_parts: [question_tool, {:user, "u-1", "Answer sent"}]})

      result = EventProcessor.maybe_load_pending_question(socket, %{pending_question: nil})
      assert result.assigns.pending_question == nil
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

  describe "process_event/2 — message.updated (user) correlation_key dedup" do
    test "removes queued message by correlation_key match (camelCase field)" do
      socket =
        build_socket(%{
          queued_messages: [
            %{
              id: "q-1",
              correlation_key: "key-abc",
              content: "fix the bug",
              queued_at: ~U[2026-03-01 00:00:00Z]
            }
          ]
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{
            "role" => "user",
            "id" => "msg-1",
            "content" => "fix the bug",
            "correlationKey" => "key-abc"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.queued_messages == []
    end

    test "removes queued message by correlation_key match (snake_case field)" do
      socket =
        build_socket(%{
          queued_messages: [
            %{
              id: "q-1",
              correlation_key: "key-xyz",
              content: "fix the bug",
              queued_at: ~U[2026-03-01 00:00:00Z]
            }
          ]
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{
            "role" => "user",
            "id" => "msg-1",
            "content" => "fix the bug",
            "correlation_key" => "key-xyz"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.queued_messages == []
    end

    test "correlation_key match takes priority over content match" do
      socket =
        build_socket(%{
          queued_messages: [
            %{
              id: "q-1",
              correlation_key: "key-first",
              content: "fix the bug",
              queued_at: ~U[2026-03-01 00:00:00Z]
            },
            %{
              id: "q-2",
              correlation_key: "key-second",
              content: "fix the bug",
              queued_at: ~U[2026-03-01 00:01:00Z]
            }
          ]
        })

      # Event matches q-2 by correlation_key, but q-1 by content (first match)
      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{
            "role" => "user",
            "id" => "msg-1",
            "content" => "fix the bug",
            "correlationKey" => "key-second"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      # Should remove q-2 (correlation_key match), not q-1 (content match)
      assert [%{id: "q-1"}] = result.assigns.queued_messages
    end

    test "falls back to content match when no correlationKey present" do
      socket =
        build_socket(%{
          queued_messages: [
            %{
              id: "q-1",
              correlation_key: "key-abc",
              content: "fix the bug",
              queued_at: ~U[2026-03-01 00:00:00Z]
            }
          ]
        })

      # No correlationKey in event — should fall back to content match
      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{"role" => "user", "id" => "msg-1", "content" => "fix the bug"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.queued_messages == []
    end

    test "falls back to content match when correlationKey doesn't match any queued message" do
      socket =
        build_socket(%{
          queued_messages: [
            %{
              id: "q-1",
              correlation_key: "key-abc",
              content: "fix the bug",
              queued_at: ~U[2026-03-01 00:00:00Z]
            }
          ]
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{
            "role" => "user",
            "id" => "msg-1",
            "content" => "fix the bug",
            "correlationKey" => "key-nonexistent"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      # Falls back to content match — removes q-1
      assert result.assigns.queued_messages == []
    end

    test "handles queued messages without correlation_key field (content fallback)" do
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
            "content" => "fix the bug",
            "correlationKey" => "key-abc"
          }
        }
      }

      # No correlation_key on the queued message — correlation_key match fails,
      # falls back to content match
      result = EventProcessor.process_event(event, socket)
      assert result.assigns.queued_messages == []
    end
  end

  describe "process_event/2 — message.part.updated promotes :answer_submitted to :user" do
    test "promotes :answer_submitted part to :user when matching user message part arrives" do
      socket =
        build_socket(%{
          output_parts: [{:answer_submitted, "optimistic-1", "Re: Deploy — Yes"}],
          optimistic_user_messages: ["Re: Deploy — Yes"],
          user_message_ids: MapSet.new(["msg-42"])
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "text",
            "id" => "part-1",
            "text" => "Re: Deploy — Yes",
            "messageID" => "msg-42"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert [{:user, _id, "Re: Deploy — Yes"}] = result.assigns.output_parts
      assert result.assigns.optimistic_user_messages == []
    end

    test "does not promote :answer_submitted when content doesn't match" do
      socket =
        build_socket(%{
          output_parts: [{:answer_submitted, "optimistic-1", "Re: Deploy — Yes"}],
          optimistic_user_messages: ["Re: Deploy — Yes"],
          user_message_ids: MapSet.new(["msg-42"])
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "text",
            "id" => "part-1",
            "text" => "something else",
            "messageID" => "msg-42"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)

      # The :answer_submitted part remains; the non-matching text gets appended separately
      assert {:answer_submitted, "optimistic-1", "Re: Deploy — Yes"} =
               Enum.find(result.assigns.output_parts, &match?({:answer_submitted, _, _}, &1))
    end
  end

  describe "process_event/2 — unknown events" do
    import ExUnit.CaptureLog

    test "returns socket unchanged for unknown event type" do
      socket = build_socket()

      event = %{"type" => "some.unknown.event", "properties" => %{}}
      result = EventProcessor.process_event(event, socket)
      assert result.assigns == socket.assigns
    end

    test "logs a debug message for unknown event types" do
      socket = build_socket()
      event = %{"type" => "some.unknown.event", "properties" => %{}}

      log =
        capture_log(fn ->
          EventProcessor.process_event(event, socket)
        end)

      assert log =~ "EventProcessor: unhandled event"
      assert log =~ "some.unknown.event"
    end

    test "does not log for explicitly skipped todo.updated events" do
      socket = build_socket()
      event = %{"type" => "todo.updated", "properties" => %{}}

      log =
        capture_log(fn ->
          EventProcessor.process_event(event, socket)
        end)

      refute log =~ "unhandled event"
    end

    test "known event types do not trigger the unknown event log" do
      socket = build_socket()

      event = %{
        "type" => "session.updated",
        "properties" => %{"info" => %{"title" => "test"}}
      }

      log =
        capture_log(fn ->
          EventProcessor.process_event(event, socket)
        end)

      refute log =~ "unhandled event"
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

    test "treats cached running tool parts as done" do
      json =
        Jason.encode!([
          %{"type" => "tool", "id" => "tool-1", "name" => "bash", "status" => "running"}
        ])

      parts = EventProcessor.decode_cached_output(json)
      assert [{:tool, "tool-1", "bash", :done, _detail}] = parts
    end

    test "falls back to plain text for non-JSON output" do
      parts = EventProcessor.decode_cached_output("just some plain text")
      assert [{:text, "cached-0", "just some plain text", :frozen}] = parts
    end

    test "decodes answer_submitted parts" do
      json =
        Jason.encode!([
          %{"type" => "answer_submitted", "id" => "a-1", "text" => "Re: Deploy — Yes"}
        ])

      parts = EventProcessor.decode_cached_output(json)
      assert [{:answer_submitted, "a-1", "Re: Deploy — Yes"}] = parts
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

    test "freezes running subtask parts to done" do
      parts = [
        {:subtask, "sub-1", %{agent: "explore", description: "d", prompt: "p", status: :running}}
      ]

      assert EventProcessor.freeze_streaming(parts) == [
               {:subtask, "sub-1",
                %{agent: "explore", description: "d", prompt: "p", status: :done}}
             ]
    end

    test "leaves done subtask parts unchanged" do
      parts = [
        {:subtask, "sub-1", %{agent: "explore", description: "d", prompt: "p", status: :done}}
      ]

      assert ^parts = EventProcessor.freeze_streaming(parts)
    end
  end

  # ---- Subtask handling ----

  describe "process_event/2 — message.part.updated (subtask)" do
    test "subtask part creates {:subtask, id, detail} in output_parts with :running status" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "subtask",
            "messageID" => "msg-sub-1",
            "id" => "sub-1",
            "sessionID" => "sess-sub",
            "prompt" => "Explore the codebase",
            "description" => "Research spike",
            "agent" => "explore"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)

      assert [{:subtask, "subtask-msg-sub-1", detail}] = result.assigns.output_parts
      assert detail.agent == "explore"
      assert detail.description == "Research spike"
      assert detail.prompt == "Explore the codebase"
      assert detail.status == :running
    end

    test "subtask part adds messageID to subtask_message_ids" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "subtask",
            "messageID" => "msg-sub-1",
            "id" => "sub-1",
            "sessionID" => "sess-sub",
            "prompt" => "Explore the codebase",
            "description" => "Research spike",
            "agent" => "explore"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert MapSet.member?(result.assigns.subtask_message_ids, "msg-sub-1")
    end

    test "subtask part with messageId (lower-camel) variant also works" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "subtask",
            "messageId" => "msg-sub-2",
            "id" => "sub-2",
            "sessionID" => "sess-sub",
            "prompt" => "Search for files",
            "description" => "Find tests",
            "agent" => "general"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert MapSet.member?(result.assigns.subtask_message_ids, "msg-sub-2")

      assert [{:subtask, "subtask-msg-sub-2", detail}] = result.assigns.output_parts
      assert detail.agent == "general"
    end

    test "subtask part with optional model and command fields still creates correct tuple" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "subtask",
            "messageID" => "msg-sub-3",
            "id" => "sub-3",
            "sessionID" => "sess-sub",
            "prompt" => "Investigate auth",
            "description" => "Auth spike",
            "agent" => "explore",
            "model" => %{"providerID" => "anthropic", "modelID" => "claude-opus-4"},
            "command" => "/explore"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)

      assert [{:subtask, "subtask-msg-sub-3", detail}] = result.assigns.output_parts
      assert detail.agent == "explore"
      assert detail.description == "Auth spike"
      assert detail.prompt == "Investigate auth"
      assert detail.status == :running
    end
  end

  describe "process_event/2 — message.updated (user) subtask suppression" do
    test "user message.updated for subtask messageID does NOT add to user_message_ids" do
      socket = build_socket(%{subtask_message_ids: MapSet.new(["msg-sub-1"])})

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{"role" => "user", "id" => "msg-sub-1"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      refute MapSet.member?(result.assigns.user_message_ids, "msg-sub-1")
    end

    test "user message.updated for subtask messageID does NOT trigger queued message dedup" do
      socket =
        build_socket(%{
          subtask_message_ids: MapSet.new(["msg-sub-1"]),
          queued_messages: [
            %{id: "q-1", content: "Explore the codebase", queued_at: ~U[2026-03-01 00:00:00Z]}
          ]
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{
            "role" => "user",
            "id" => "msg-sub-1",
            "content" => "Explore the codebase"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert [%{id: "q-1"}] = result.assigns.queued_messages
    end

    test "normal user message.updated still tracks correctly (regression)" do
      socket = build_socket(%{subtask_message_ids: MapSet.new()})

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{"role" => "user", "id" => "msg-normal-1"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert MapSet.member?(result.assigns.user_message_ids, "msg-normal-1")
    end
  end

  describe "process_event/2 — message.part.updated (text) subtask suppression" do
    test "text part for subtask messageID is suppressed" do
      socket =
        build_socket(%{
          subtask_message_ids: MapSet.new(["msg-sub-1"]),
          user_message_ids: MapSet.new()
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "id" => "part-sub-1",
            "type" => "text",
            "text" => "Explore the codebase",
            "messageID" => "msg-sub-1"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.output_parts == []
    end

    test "text part for normal messageID still renders (regression)" do
      socket =
        build_socket(%{
          subtask_message_ids: MapSet.new(),
          user_message_ids: MapSet.new()
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "id" => "part-1",
            "type" => "text",
            "text" => "Hello world",
            "messageID" => "msg-normal-1"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert [{:text, "part-1", "Hello world", :streaming}] = result.assigns.output_parts
    end

    test "text part for user messageID still routes to user message caching (regression)" do
      socket =
        build_socket(%{
          subtask_message_ids: MapSet.new(),
          user_message_ids: MapSet.new(["msg-user-1"])
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "id" => "part-u-1",
            "type" => "text",
            "text" => "User typed this",
            "messageID" => "msg-user-1"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert [{:user, "msg-user-1", "User typed this"}] = result.assigns.output_parts
    end
  end

  describe "process_event/2 — session event isolation" do
    test "child session user message.updated does NOT add to user_message_ids" do
      socket =
        build_socket(%{
          parent_session_id: "parent-sess",
          child_session_ids: MapSet.new(["child-sess"]),
          user_message_ids: MapSet.new(),
          subtask_message_ids: MapSet.new(),
          output_parts: []
        })

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "sessionID" => "child-sess",
          "info" => %{"role" => "user", "id" => "msg-1", "content" => "Explore the code"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      refute MapSet.member?(result.assigns.user_message_ids, "msg-1")
    end

    test "child session text part does NOT add to output_parts" do
      socket =
        build_socket(%{
          parent_session_id: "parent-sess",
          child_session_ids: MapSet.new(["child-sess"]),
          output_parts: [],
          user_message_ids: MapSet.new(),
          subtask_message_ids: MapSet.new()
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "sessionID" => "child-sess",
          "part" => %{"type" => "text", "id" => "part-1", "text" => "some output"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert result.assigns.output_parts == []
    end

    test "event without sessionID processes normally (backward compat)" do
      socket =
        build_socket(%{
          parent_session_id: "parent-sess",
          child_session_ids: MapSet.new(),
          output_parts: [],
          user_message_ids: MapSet.new(),
          subtask_message_ids: MapSet.new()
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"type" => "text", "id" => "part-1", "text" => "hello"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert length(result.assigns.output_parts) == 1
    end

    test "parent session event with matching sessionID processes normally" do
      socket =
        build_socket(%{
          parent_session_id: "parent-sess",
          child_session_ids: MapSet.new(),
          output_parts: [],
          user_message_ids: MapSet.new(),
          subtask_message_ids: MapSet.new()
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "sessionID" => "parent-sess",
          "part" => %{"type" => "text", "id" => "part-1", "text" => "hello"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert length(result.assigns.output_parts) == 1
    end

    test "event processes normally when parent_session_id assign is nil" do
      socket =
        build_socket(%{
          output_parts: [],
          user_message_ids: MapSet.new(),
          subtask_message_ids: MapSet.new()
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "sessionID" => "some-sess",
          "part" => %{"type" => "text", "id" => "part-1", "text" => "hello"}
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert length(result.assigns.output_parts) == 1
    end

    test "subtask part event from child session is still processed (not filtered)" do
      socket =
        build_socket(%{
          parent_session_id: "parent-sess",
          child_session_ids: MapSet.new(["child-sess"]),
          output_parts: [],
          user_message_ids: MapSet.new(),
          subtask_message_ids: MapSet.new()
        })

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "sessionID" => "child-sess",
          "part" => %{
            "type" => "subtask",
            "id" => "part-1",
            "messageID" => "msg-1",
            "agent" => "explore",
            "description" => "Research spike",
            "prompt" => "Find the files"
          }
        }
      }

      result = EventProcessor.process_event(event, socket)
      assert length(result.assigns.output_parts) == 1
      assert {:subtask, _, %{agent: "explore"}} = hd(result.assigns.output_parts)
    end
  end

  describe "decode_cached_output/1 — subtask entries" do
    test "decodes subtask cache entry into {:subtask, id, detail} tuple with :done status" do
      json =
        Jason.encode!([
          %{
            "type" => "subtask",
            "id" => "subtask-msg-1",
            "agent" => "explore",
            "description" => "Research spike",
            "prompt" => "Explore the codebase",
            "status" => "running"
          }
        ])

      parts = EventProcessor.decode_cached_output(json)

      assert [
               {:subtask, "subtask-msg-1",
                %{
                  agent: "explore",
                  description: "Research spike",
                  prompt: "Explore the codebase",
                  status: :done
                }}
             ] = parts
    end
  end

  describe "decode_cached_output/1 — backport subagent prompt re-attribution" do
    test "user part after task tool is re-attributed as subtask" do
      json =
        Jason.encode!([
          %{
            "type" => "tool",
            "id" => "tool-1",
            "name" => "task",
            "status" => "done",
            "input" => %{"prompt" => "Explore the codebase", "description" => "Research spike"}
          },
          %{"type" => "user", "id" => "user-1", "text" => "Explore the codebase"}
        ])

      parts = EventProcessor.decode_cached_output(json)

      assert [
               {:tool, "tool-1", "task", :done, _tool_detail},
               {:subtask, "user-1",
                %{agent: "unknown", prompt: "Explore the codebase", status: :done}}
             ] = parts
    end

    test "user part NOT after task tool remains as user (regression)" do
      json =
        Jason.encode!([
          %{"type" => "text", "id" => "text-1", "text" => "Hello"},
          %{"type" => "user", "id" => "user-1", "text" => "Follow-up"}
        ])

      parts = EventProcessor.decode_cached_output(json)
      assert {:user, "user-1", "Follow-up"} in parts
    end

    test "user part after non-task tool is NOT re-attributed" do
      json =
        Jason.encode!([
          %{"type" => "tool", "id" => "tool-1", "name" => "read_file", "status" => "done"},
          %{"type" => "user", "id" => "user-1", "text" => "Follow-up question"}
        ])

      parts = EventProcessor.decode_cached_output(json)

      assert Enum.any?(parts, fn
               {:user, "user-1", "Follow-up question"} -> true
               _ -> false
             end)
    end
  end

  describe "has_streaming_parts?/1 — subtask" do
    test "returns true when there are running subtask parts" do
      assert EventProcessor.has_streaming_parts?([
               {:subtask, "sub-1", %{status: :running}}
             ])
    end

    test "returns false when subtask is done" do
      refute EventProcessor.has_streaming_parts?([
               {:subtask, "sub-1", %{status: :done}}
             ])
    end
  end

  describe "process_event/2 — message.part.updated catch-all (unmatched variants)" do
    import ExUnit.CaptureLog

    test "empty reasoning text does not trigger unhandled event warning" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"id" => "r-1", "type" => "reasoning", "text" => ""}
        }
      }

      log =
        capture_log(fn ->
          result = EventProcessor.process_event(event, socket)
          assert result.assigns.output_parts == []
        end)

      refute log =~ "unhandled event"
    end

    test "tool part without state.status does not trigger unhandled event warning" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"type" => "tool", "id" => "tool-1", "name" => "bash"}
        }
      }

      log =
        capture_log(fn ->
          result = EventProcessor.process_event(event, socket)
          assert result.assigns.output_parts == []
        end)

      refute log =~ "unhandled event"
    end

    test "unknown part type does not trigger unhandled event warning" do
      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"type" => "file", "id" => "f-1", "path" => "/tmp/test.txt"}
        }
      }

      log =
        capture_log(fn ->
          result = EventProcessor.process_event(event, socket)
          assert result.assigns.output_parts == []
        end)

      refute log =~ "unhandled event"
    end

    test "does not emit :unhandled telemetry for unmatched message.part.updated" do
      test_pid = self()
      handler_id = "test-mpu-catchall-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:agents_web, :event_processor, :unhandled],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

      socket = build_socket()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"type" => "image", "id" => "img-1"}
        }
      }

      EventProcessor.process_event(event, socket)

      refute_received {:telemetry_event, [:agents_web, :event_processor, :unhandled], _, _}

      :telemetry.detach(handler_id)
    end
  end

  describe "process_event/2 — telemetry for unhandled events" do
    setup do
      test_pid = self()

      handler_id = "test-unhandled-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:agents_web, :event_processor, :unhandled],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
      :ok
    end

    test "emits telemetry for events with unrecognized type" do
      socket = build_socket()
      EventProcessor.process_event(%{"type" => "unknown.event"}, socket)

      assert_received {:telemetry_event, [:agents_web, :event_processor, :unhandled], %{count: 1},
                       %{type: "unknown.event"}}
    end

    test "emits telemetry for events without a type key" do
      socket = build_socket()
      EventProcessor.process_event(%{"no_type" => true}, socket)

      assert_received {:telemetry_event, [:agents_web, :event_processor, :unhandled], %{count: 1},
                       %{type: nil}}
    end

    test "does not emit :unhandled telemetry for todo.updated (explicit skip)" do
      socket = build_socket()
      EventProcessor.process_event(%{"type" => "todo.updated"}, socket)

      refute_received {:telemetry_event, [:agents_web, :event_processor, :unhandled], _, _}
    end

    test "does not emit :unhandled telemetry for known event types" do
      socket = build_socket()

      EventProcessor.process_event(
        %{"type" => "session.updated", "properties" => %{"info" => %{}}},
        socket
      )

      refute_received {:telemetry_event, [:agents_web, :event_processor, :unhandled], _, _}
    end
  end
end
