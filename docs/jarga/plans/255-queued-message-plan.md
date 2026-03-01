# Feature: Show User's Queued Message in Chat View (#255)

## Overview

When a user sends a message while the assistant is still streaming a response, the message should be queued and displayed visually in the chat with distinct "queued" styling. Once streaming completes, queued messages are dequeued and processed sequentially. This is implemented as **transient UI state** in the LiveComponent — no DB migration, no schema changes.

## UI Strategy

- **LiveView coverage**: 100%
- **TypeScript needed**: None — all logic is server-side LiveComponent state management + template rendering

## Affected Boundaries

- **Owning app (domain)**: `jarga` (chat context — but **NO domain changes needed**)
- **Owning app (interface)**: `jarga_web`
- **Repo**: `Jarga.Repo` (no new migrations)
- **Migrations**: None
- **Feature files**: `apps/jarga_web/test/features/chat/`
- **Primary context**: `JargaWeb.ChatLive.Panel` (LiveComponent — interface layer only)
- **Dependencies**: `Jarga.Chat` (existing public API, no changes)
- **Exported schemas**: None
- **New context needed?**: No — this is purely an interface-layer enhancement

## Architecture Decision: Cancel Behaviour

**Decision: Discard queued messages on cancel.**

Rationale:
1. The user explicitly cancelled the streaming response — this signals "stop everything"
2. Queued messages were typed in the context of an ongoing conversation; cancelling invalidates that context
3. Keeping queued messages after cancel creates confusing UX: the user would see queued messages auto-fire after they explicitly stopped
4. This matches the mental model of "cancel = abort the current flow"
5. The user's text is not lost — they can re-type or use browser history

The cancel handler will clear `queued_messages` and show a brief flash or info message if messages were discarded.

## Architecture Decision: Queued Message Data Structure

```elixir
%{
  id: String.t(),          # UUID generated client-side or via Ecto.UUID.generate()
  content: String.t(),     # The message text
  timestamp: DateTime.t()  # When the user submitted it
}
```

Stored in assign `queued_messages: []` (a list, ordered by submission time).

## Key Files Modified

| File | Change Type |
|------|-------------|
| `apps/jarga_web/lib/live/chat_live/panel.ex` | Add `queued_messages` assign, modify `send_message`, `handle_done`, `cancel_streaming`, `new_conversation`, `clear_chat` |
| `apps/jarga_web/lib/live/chat_live/panel.html.heex` | Enable input during streaming, render queued messages, update button states |
| `apps/jarga_web/lib/live/chat_live/components/message.ex` | Add `status` attribute (`:sent` / `:queued`), queued styling |
| `apps/jarga_web/test/live/chat_live/panel_test.exs` | New test cases for all queued message behaviour |
| `apps/jarga_web/test/features/chat/queued_messages.browser.feature` | New BDD feature file |

## Implementation Phases

---

### Phase 1: Add `queued_messages` Assign and Queue-on-Send Logic

**Goal**: When `@streaming` is true and user sends a message, append to `queued_messages` instead of calling `process_message`. Input remains enabled during streaming.

#### Step 1.1: Initialize `queued_messages` assign in mount

- ⏸ **RED**: Write test `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - `describe "queued messages"` block
  - Test: "initializes with empty queued_messages" — verify panel mounts without error (implicit: no crash means assign exists)
  - Test: "textarea is enabled during streaming" — send a message, verify `#chat-input` is NOT disabled while streaming is active
  - Test: "send button is enabled during streaming when input has text" — type text while streaming, verify submit button is not disabled
- ⏸ **GREEN**: Modify `apps/jarga_web/lib/live/chat_live/panel.ex`
  - Add `|> assign(:queued_messages, [])` in `mount/1`
  - Modify `apps/jarga_web/lib/live/chat_live/panel.html.heex`:
    - Remove `disabled={@streaming}` from textarea (line 206)
    - Change send button `disabled` from `@streaming or @current_message == ""` to `@current_message == ""` (line 233)
    - Update placeholder to show "Type a message to queue..." when streaming, "Ask about this document..." otherwise
- ⏸ **REFACTOR**: Clean up — ensure existing streaming tests still pass with the changed disabled logic

#### Step 1.2: Queue message when streaming is active

- ⏸ **RED**: Write tests in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "queues message when streaming is active" — send first message (triggers streaming), then submit a second message; verify second message appears in chat with queued styling, verify it was NOT persisted to DB yet
  - Test: "queued message appears in chat message list" — after queuing, verify the queued message text is visible in `#chat-messages`
  - Test: "queued message has queued indicator" — verify the queued message element has a "Queued" text indicator or a distinguishing CSS class
  - Test: "multiple messages can be queued in order" — queue 2 messages during streaming, verify both appear in order
  - Test: "empty message is not queued" — submit empty text during streaming, verify no queued message added
- ⏸ **GREEN**: Modify `handle_event("send_message", ...)` in `apps/jarga_web/lib/live/chat_live/panel.ex`
  - Add branching logic:
    ```elixir
    if socket.assigns.streaming do
      queue_message(socket, message_text)
    else
      socket
      |> process_message(message_text)
      |> send_chat_response()
    end
    ```
  - Implement `queue_message/2`:
    ```elixir
    defp queue_message(socket, message_text) do
      queued_msg = %{
        id: Ecto.UUID.generate(),
        content: message_text,
        timestamp: DateTime.utc_now()
      }
      {:noreply,
       socket
       |> assign(:queued_messages, socket.assigns.queued_messages ++ [queued_msg])
       |> assign(:current_message, "")
       |> push_event("scroll_to_bottom", %{})}
    end
    ```
- ⏸ **REFACTOR**: Extract `queue_message/2` helper, ensure it's well-documented

#### Step 1.3: Render queued messages in template

- ⏸ **RED**: Write tests in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "queued messages render after streaming indicator" — verify DOM order: regular messages, then streaming bubble, then queued messages
  - Test: "queued messages have muted styling" — check for opacity/dimmed class on queued message elements
- ⏸ **GREEN**: Modify `apps/jarga_web/lib/live/chat_live/panel.html.heex`
  - After the streaming indicator block (after line 180), add:
    ```heex
    <%= for queued_msg <- @queued_messages do %>
      <.message
        message={%{
          id: queued_msg.id,
          role: "user",
          content: queued_msg.content,
          timestamp: queued_msg.timestamp
        }}
        status={:queued}
        show_insert={false}
        panel_target={@myself}
      />
    <% end %>
    ```
- ⏸ **REFACTOR**: Ensure template is clean and well-commented

#### Phase 1 Validation
- ⏸ All queued message creation tests pass
- ⏸ Existing streaming tests still pass (textarea disabled tests will need updating)
- ⏸ No boundary violations (`mix boundary`)

---

### Phase 2: Process Queued Messages After Streaming Completes

**Goal**: When streaming finishes (`:done`), dequeue the first queued message and process it, creating a sequential chain.

#### Step 2.1: Dequeue and process after `:done`

- ⏸ **RED**: Write tests in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "processes first queued message after streaming completes" — send message, queue a second during streaming, simulate `:done`; verify the queued message transitions to a regular sent message and triggers a new streaming cycle
  - Test: "queued message is saved to DB when processed" — after dequeue + process, verify `Chat.load_session` contains the previously-queued message
  - Test: "queued message creates session if none exists" — edge case: if somehow the session is nil when dequeuing, `ensure_session` is called
  - Test: "streaming restarts for dequeued message" — verify `@streaming` is true again after dequeue
- ⏸ **GREEN**: Modify `handle_done/2` in `apps/jarga_web/lib/live/chat_live/panel.ex`
  - After existing logic (save assistant message, append to messages, set streaming: false), add:
    ```elixir
    |> maybe_process_queued_message()
    ```
  - Implement `maybe_process_queued_message/1`:
    ```elixir
    defp maybe_process_queued_message(socket) do
      case socket.assigns.queued_messages do
        [next_msg | remaining] ->
          socket
          |> assign(:queued_messages, remaining)
          |> process_message(next_msg.content)
          # Note: send_chat_response is called separately
        [] ->
          socket
      end
    end
    ```
  - **Important**: The return from `handle_done` must be adjusted. Currently `handle_done` returns a socket (not a `{:noreply, socket}`). The `maybe_process_queued_message` needs to also call `send_chat_response` if there's a queued message. Since `handle_done` is called from `handle_streaming_updates` (inside `update/2`), we need to handle this carefully:
    - Option A: Use `send(self(), {:process_queued_message})` to trigger processing in the next cycle
    - Option B: Directly call process + trigger from within update
    - **Chosen**: Option A — send a message to self for cleaner separation. The parent LiveView's `handle_info` will forward it via `send_update`.
  - Actually, re-examining: `handle_done` is called during `update/2`. We can't call `send_chat_response` (which calls `Agents.chat_stream` and returns `{:noreply, socket}`) from `update/2`. So we must use a deferred approach:
    - In `handle_done`, after detecting queued messages, `send(self(), {:process_next_queued_message})`
    - Add a new `handle_info` clause in `message_handlers.ex` to forward this to the panel
    - The panel processes it in a subsequent `update/2` call
- ⏸ **REFACTOR**: Clean up the deferred processing pattern, add documentation

#### Step 2.2: Add message handler for deferred queue processing

- ⏸ **RED**: Write test in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "deferred queue processing triggers new streaming" — simulate `:done`, verify `{:process_next_queued_message}` is sent and panel processes it
- ⏸ **GREEN**: Modify `apps/jarga_web/lib/live/chat_live/message_handlers.ex`
  - Add new handler:
    ```elixir
    @impl true
    def handle_info({:process_next_queued_message}, socket) do
      Phoenix.LiveView.send_update(JargaWeb.ChatLive.Panel,
        id: "global-chat-panel",
        process_queued: true
      )
      {:noreply, socket}
    end
    ```
  - Modify `handle_streaming_updates/2` in `panel.ex` to handle `process_queued` assign:
    ```elixir
    Map.has_key?(assigns, :process_queued) ->
      process_next_queued_message(socket)
    ```
  - Implement `process_next_queued_message/1` in panel.ex:
    ```elixir
    defp process_next_queued_message(socket) do
      case socket.assigns.queued_messages do
        [next_msg | remaining] ->
          socket = assign(socket, :queued_messages, remaining)
          socket = process_message(socket, next_msg.content)
          # Trigger streaming in the parent
          send_chat_response_from_update(socket)
        [] ->
          socket
      end
    end
    ```
  - Since `send_chat_response` returns `{:noreply, socket}`, extract its core logic into a helper that can be called from update:
    ```elixir
    defp trigger_chat_stream(socket) do
      llm_messages = socket.assigns.llm_messages
      llm_opts = socket.assigns.llm_opts

      case Agents.chat_stream(llm_messages, self(), llm_opts) do
        {:ok, _pid} -> socket
        {:error, reason} ->
          send(self(), {:put_flash, :error, "Chat error: #{reason}"})
          assign(socket, :streaming, false)
      end
    end
    ```
- ⏸ **REFACTOR**: Unify `send_chat_response/1` and `trigger_chat_stream/1` to avoid duplication

#### Step 2.3: Sequential processing of multiple queued messages

- ⏸ **RED**: Write tests in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "processes multiple queued messages sequentially" — queue 2 messages during streaming, simulate `:done` twice; verify both messages are processed in order, each triggering its own streaming cycle
  - Test: "queued message list shrinks as messages are processed" — verify `@queued_messages` decreases by one after each `:done`
- ⏸ **GREEN**: The implementation from 2.1/2.2 should handle this naturally since each `:done` triggers processing of the next queued message
- ⏸ **REFACTOR**: Verify the chain works correctly, add logging for debugging

#### Phase 2 Validation
- ⏸ All dequeue/process tests pass
- ⏸ Sequential processing chain works for 1, 2, and 3+ queued messages
- ⏸ Messages are correctly persisted to DB when processed
- ⏸ No boundary violations

---

### Phase 3: Visual Distinction for Queued Messages

**Goal**: Queued messages are visually distinct from sent messages with muted styling and a "Queued" indicator.

#### Step 3.1: Add `status` attribute to message component

- ⏸ **RED**: Write tests in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "queued message has opacity-50 class" — verify queued messages render with reduced opacity
  - Test: "queued message shows 'Queued' label" — verify a "Queued" text badge appears
  - Test: "queued message does not show delete link" — queued messages have no DB ID yet, so no delete
  - Test: "queued message does not show timestamp header" — or shows a "Pending" timestamp
  - Test: "sent messages retain normal styling" — existing messages unaffected by status attribute
- ⏸ **GREEN**: Modify `apps/jarga_web/lib/live/chat_live/components/message.ex`
  - Add new attribute:
    ```elixir
    attr :status, :atom, default: :sent, values: [:sent, :queued]
    ```
  - Modify the outer `div` class to include opacity for queued:
    ```elixir
    <div class={[
      "chat #{if @message.role == "user", do: "chat-end", else: "chat-start"}",
      @status == :queued && "opacity-50"
    ]}>
    ```
  - Modify the chat-header to show "Queued" for queued messages:
    ```elixir
    <%= if @status == :queued do %>
      <div class="chat-header opacity-50 text-xs flex items-center gap-1">
        <.icon name="hero-clock" class="w-3 h-3" />
        <span>Queued</span>
      </div>
    <% else %>
      <%= if !Map.get(@message, :streaming, false) do %>
        <div class="chat-header opacity-50 text-xs">
          {format_timestamp(@message.timestamp)}
        </div>
      <% end %>
    <% end %>
    ```
  - Suppress footer (delete/insert) for queued messages — adjust `should_show_footer?` to check status
- ⏸ **REFACTOR**: Ensure existing message component tests still pass, refine styling

#### Step 3.2: Update template to pass status to message component

- ⏸ **RED**: Write test in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "regular messages pass status :sent to component" — verify existing messages don't show "Queued"
  - Test: "queued messages pass status :queued to component" — verify queued messages show "Queued"
- ⏸ **GREEN**: Modify `apps/jarga_web/lib/live/chat_live/panel.html.heex`
  - Add `status={:sent}` to the regular message loop (line 145-149)
  - Add `status={:queued}` to the queued message loop (from Phase 1, Step 1.3)
  - The streaming message gets `status={:sent}` (it's an active response, not queued)
- ⏸ **REFACTOR**: Clean up, verify visual consistency

#### Step 3.3: Queued message transitions to sent state

- ⏸ **RED**: Write test in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "queued message transitions to normal styling when processed" — queue a message, simulate `:done`, verify the message now appears as a regular sent message (full opacity, timestamp, delete link)
- ⏸ **GREEN**: This should work automatically because `process_message/2` adds the message to `@messages` with a DB-persisted `id` and removes it from `@queued_messages`
- ⏸ **REFACTOR**: Verify smooth visual transition

#### Phase 3 Validation
- ⏸ All visual styling tests pass
- ⏸ Message component handles both `:sent` and `:queued` statuses
- ⏸ Queued messages are visually distinguishable from sent messages
- ⏸ No boundary violations

---

### Phase 4: Edge Cases and Robustness

**Goal**: Handle cancellation, new conversation, clear chat, and other edge cases with queued messages.

#### Step 4.1: Cancel streaming discards queued messages

- ⏸ **RED**: Write tests in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "cancel_streaming clears queued messages" — queue messages during streaming, click cancel; verify `@queued_messages` is empty and queued messages disappear from the UI
  - Test: "cancel_streaming with queued messages shows info" — verify flash or indicator that queued messages were discarded (optional: just verify they're gone)
  - Test: "cancel_streaming with no queued messages works as before" — existing cancel behaviour unchanged
- ⏸ **GREEN**: Modify `handle_event("cancel_streaming", ...)` in `panel.ex`
  - Add `|> assign(:queued_messages, [])` to both branches (with and without stream_buffer)
- ⏸ **REFACTOR**: Clean up

#### Step 4.2: New conversation clears queued messages

- ⏸ **RED**: Write test in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "new_conversation clears queued messages" — queue messages, click "New conversation"; verify queued messages are cleared
- ⏸ **GREEN**: Modify `handle_event("new_conversation", ...)` in `panel.ex`
  - Add `|> assign(:queued_messages, [])`
- ⏸ **REFACTOR**: Clean up

#### Step 4.3: Clear chat clears queued messages

- ⏸ **RED**: Write test in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "clear_chat clears queued messages" — queue messages, click clear; verify queued messages are cleared
- ⏸ **GREEN**: Modify `handle_event("clear_chat", ...)` in `panel.ex`
  - Add `|> assign(:queued_messages, [])`
- ⏸ **REFACTOR**: Clean up

#### Step 4.4: Error during streaming with queued messages

- ⏸ **RED**: Write test in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "error during streaming discards queued messages" — queue messages, simulate `:error`; verify queued messages are cleared (same as cancel — error is an abnormal end, don't auto-process)
- ⏸ **GREEN**: Modify `handle_error/2` in `panel.ex`
  - Add `|> assign(:queued_messages, [])`
- ⏸ **REFACTOR**: Clean up

#### Step 4.5: Session creation for queued messages

- ⏸ **RED**: Write test in `apps/jarga_web/test/live/chat_live/panel_test.exs`
  - Test: "queued message reuses existing session when processed" — first message creates session, queued message should use same session
  - Test: "first message in fresh chat creates session, queued messages follow" — verify session continuity
- ⏸ **GREEN**: No new code needed — `process_message/2` already calls `ensure_session/2` which checks for existing `current_session_id`
- ⏸ **REFACTOR**: Verify no double-session creation

#### Step 4.6: Update existing tests for new input behaviour

- ⏸ **RED**: Identify existing tests that assert `disabled` on textarea/send button during streaming
  - `"disables input while streaming"` (line 168) — needs update
  - `"Send button disabled during streaming"` BDD scenario — needs update
  - `"placeholder shows default text when not streaming"` — check placeholder changes
- ⏸ **GREEN**: Update failing tests to reflect new behaviour:
  - Textarea is now enabled during streaming (remove `assert has_element?(view, "#chat-input[disabled]")`)
  - Send button is enabled when text is present during streaming
  - Placeholder changes to "Type a message to queue..." during streaming
- ⏸ **REFACTOR**: Ensure all existing tests pass with new behaviour

#### Phase 4 Validation
- ⏸ All edge case tests pass
- ⏸ Cancel, new conversation, clear, and error all properly clear queued messages
- ⏸ Updated existing tests pass
- ⏸ Full test suite passes (`mix test apps/jarga_web`)
- ⏸ No boundary violations

---

### Phase 5: BDD Feature Files

**Goal**: Create browser-level BDD feature files for the queued message behaviour.

#### Step 5.1: Create queued messages feature file

- ⏸ **RED/GREEN**: Create `apps/jarga_web/test/features/chat/queued_messages.browser.feature`
  - Scenarios:
    1. "Queue a message while assistant is streaming" — send message, type second message while streaming, submit; verify queued message visible with "Queued" indicator
    2. "Queued message transitions to sent after streaming completes" — wait for streaming to complete; verify queued message loses "Queued" indicator and triggers new response
    3. "Multiple queued messages shown in order" — queue 2 messages, verify both visible in order
    4. "Cancel streaming discards queued messages" — queue a message, cancel streaming; verify queued message disappears
    5. "Input remains enabled during streaming" — send message, verify textarea is not disabled during streaming
- ⏸ **REFACTOR**: Ensure feature file follows existing patterns in `messaging.browser.feature` and `streaming.browser.feature`

#### Step 5.2: Update existing streaming feature file

- ⏸ **RED/GREEN**: Modify `apps/jarga_web/test/features/chat/streaming.browser.feature`
  - Update "Send button disabled during streaming" scenario — this is no longer true; remove or invert the assertion
  - Update any scenarios that rely on textarea being disabled during streaming
- ⏸ **REFACTOR**: Ensure updated features are tagged appropriately (`@wip` for LLM-dependent ones)

#### Phase 5 Validation
- ⏸ New BDD feature file exists and is syntactically valid
- ⏸ Existing BDD feature files updated for new behaviour
- ⏸ Feature files follow existing patterns (Background, selectors, wait strategies)

---

## Pre-Commit Checkpoint

After completing all phases:

- ⏸ `mix format` passes
- ⏸ `mix credo` passes
- ⏸ `mix boundary` shows no violations
- ⏸ `mix test apps/jarga_web` — all tests pass
- ⏸ `mix test apps/jarga` — all domain tests still pass (no domain changes)
- ⏸ `mix precommit` passes

## Testing Strategy

- **Total estimated tests**: ~22-25 new tests
- **Distribution**:
  - Domain: 0 (no domain changes)
  - Application: 0 (no use case changes)
  - Infrastructure: 0 (no repository/schema changes)
  - Interface (LiveComponent): ~20-22 tests in `panel_test.exs`
  - Interface (Component): ~3-5 tests for message component styling
  - BDD: 5-7 scenarios in feature files
- **Updated existing tests**: ~3-5 tests modified for new input behaviour

## Key Implementation Notes

1. **`handle_done` cannot call `send_chat_response` directly** because it runs inside `update/2`. Use `send(self(), {:process_next_queued_message})` deferred pattern.

2. **`process_message/2` must be refactored** to extract the streaming trigger into a separate function callable from both `handle_event` and `update/2` contexts.

3. **The `send_chat_response/1` function currently returns `{:noreply, socket}`** — it's designed for `handle_event`. Extract `trigger_chat_stream/1` that returns just `socket` for use in `update/2` via deferred message.

4. **Template rendering order** (after changes):
   - Empty state (when no messages, no streaming, no queued)
   - `for message <- @messages` — regular sent messages
   - Streaming indicator (Thinking... or streaming bubble)
   - `for queued_msg <- @queued_messages` — queued messages with muted styling
   - Input area (always enabled)

5. **Existing test updates needed**:
   - `"disables input while streaming"` → `"input remains enabled during streaming"`
   - `"Send button disabled during streaming"` BDD → Remove/update
   - `"placeholder shows default text when not streaming"` → Add test for streaming placeholder

6. **Message handler chain**: `:done` → `handle_done` → `send(self(), {:process_next_queued_message})` → parent `handle_info` → `send_update(Panel, process_queued: true)` → panel `update/2` → `process_next_queued_message` → `process_message` + `trigger_chat_stream` → streaming starts → next `:done` → repeat.
