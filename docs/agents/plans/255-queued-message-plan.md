# Feature: Show User's Queued Message in Chat View (#255)

## Overview

When a user sends a message while the agent is still processing (task is running), the message is sent to opencode which queues it internally. Currently, the user gets **no visual feedback** — the form clears and the message "disappears". This fix adds transient UI state to show queued messages immediately in the output log with a muted "Queued" indicator, and cleans them up when opencode processes them.

## UI Strategy

- **LiveView coverage**: 100%
- **TypeScript needed**: None — this is purely server-side LiveView assign management + template rendering

## Affected Boundaries

- **Owning app**: `agents_web` (interface layer — all changes are UI state)
- **Domain app**: `agents` — NO changes needed (Sessions.send_message already works)
- **Repo**: None — no database changes (transient LiveView assigns only)
- **Migrations**: None
- **Feature files**: `apps/agents_web/test/features/sessions/sessions.browser.feature`
- **Primary context**: N/A — this is interface-layer-only
- **Dependencies**: `Agents.Sessions` (existing public API, unchanged)
- **Exported schemas**: None
- **New context needed?**: No
- **Boundary violations**: None — all changes within `agents_web`

## Design Decisions

1. **Cancel task with queued messages**: Preserve queued messages (user may resume the session with those messages still relevant)
2. **Task completion/failure**: Clear remaining queued messages (terminal state = fresh slate; cancel is excluded — see #1)
3. **New session / select session / delete session**: Clear queued messages (switching context)
4. **Cleanup trigger**: When EventProcessor receives `message.updated` with `role=user`, match by content against `queued_messages` and remove the first matching entry
5. **Data structure**: `queued_messages: []` — list of `%{id: uuid, content: string, queued_at: DateTime}`
6. **Multiple queued messages**: Supported — rendered in order after output_parts

## Files Modified

| File | Change |
|------|--------|
| `apps/agents_web/lib/live/sessions/index.ex` | Add `queued_messages` assign in `assign_session_state/1` and `mount/1`; modify `send_message_to_running_task/2` to append queued message; clear queued messages on completion/failure/new_session/select_session/delete_session (NOT on cancel) |
| `apps/agents_web/lib/live/sessions/index.html.heex` | Render queued messages after output_parts section |
| `apps/agents_web/lib/live/sessions/event_processor.ex` | Accept `queued_messages` in base assigns; on `message.updated` with `role=user`, match and remove from `queued_messages` |
| `apps/agents_web/lib/live/sessions/components/session_components.ex` | Add `queued_message/1` component |

## Test Files

| File | Type |
|------|------|
| `apps/agents_web/test/live/sessions/event_processor_test.exs` | Unit (ExUnit.Case, async: true) |
| `apps/agents_web/test/live/sessions/components/session_components_test.exs` | Unit (ExUnit.Case, async: true) |
| `apps/agents_web/test/live/sessions/index_test.exs` | Integration (ConnCase, async: true) |
| `apps/agents_web/test/features/sessions/sessions.browser.feature` | BDD browser |

---

## Phase 1: EventProcessor — Queued Message Cleanup Logic

> Unit tests for the core cleanup logic in EventProcessor. This is the "domain" of this change — the pure logic that matches incoming user messages against queued messages.

### Step 1.1: EventProcessor tracks user message.updated and removes matching queued message

- [ ] ⏸ **RED**: Add tests to `apps/agents_web/test/live/sessions/event_processor_test.exs`
  ```
  describe "process_event/2 — message.updated (user) queued message cleanup" do
    test "removes matching queued message by content when user message.updated arrives"
    test "removes only the first matching queued message (preserves later duplicates)"
    test "leaves queued_messages unchanged when no content match"
    test "leaves queued_messages unchanged when queued_messages is empty"
    test "handles queued_messages assign not present (backward compat)"
  end
  ```
  - Build socket with `queued_messages: [%{id: "q-1", content: "fix the bug", queued_at: ~U[...]}]`
  - Send `message.updated` event with `role=user` and content "fix the bug"
  - Assert the matching queued message is removed
  - Assert unmatched messages remain

- [ ] ⏸ **GREEN**: Modify `apps/agents_web/lib/live/sessions/event_processor.ex`
  - In the existing `process_event` clause for `message.updated` with `role=user`:
    - After adding `msg_id` to `user_message_ids`, also check if event `info` has a `"content"` or `"parts"` field
    - Extract the text content from the user message event
    - Match against `queued_messages` by content (trimmed string comparison)
    - Remove the first matching entry from `queued_messages`
  - Handle the case where `queued_messages` key may not exist in assigns (backward compat with `Map.get(socket.assigns, :queued_messages, [])`)

- [ ] ⏸ **REFACTOR**: Extract `remove_matching_queued_message/2` as a private helper

### Phase 1 Validation

- [ ] ⏸ All EventProcessor tests pass: `mix test apps/agents_web/test/live/sessions/event_processor_test.exs`
- [ ] ⏸ No boundary violations

---

## Phase 2: Queued Message Component

> Add the `queued_message/1` function component to SessionComponents. Test in isolation with `render_component/2`.

### Step 2.1: Add queued_message component

- [ ] ⏸ **RED**: Add tests to `apps/agents_web/test/live/sessions/components/session_components_test.exs`
  ```
  describe "queued_message/1" do
    test "renders message content"
    test "renders 'Queued' indicator"
    test "renders with muted/dimmed styling (opacity or specific classes)"
    test "renders user avatar icon"
    test "renders relative timestamp"
    test "has data-testid attribute for testing"
  end
  ```
  - Use `render_component(&SessionComponents.queued_message/1, message: %{id: "q-1", content: "fix the bug", queued_at: DateTime.utc_now()})`
  - Assert content text is visible
  - Assert "Queued" label is present
  - Assert muted styling classes (e.g., `opacity-60`, `text-base-content/50`)
  - Assert `data-testid="queued-message-q-1"` attribute

- [ ] ⏸ **GREEN**: Add to `apps/agents_web/lib/live/sessions/components/session_components.ex`
  ```elixir
  attr(:message, :map, required: true)

  def queued_message(assigns) do
    ~H"""
    <div data-testid={"queued-message-#{@message.id}"} class="flex gap-2 mb-3 opacity-60">
      <div class="shrink-0 size-6 rounded-full bg-primary/10 flex items-center justify-center">
        <.icon name="hero-user" class="size-3.5 text-primary" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-0.5">
          <span class="text-xs font-medium text-base-content/50">You</span>
          <span class="badge badge-xs badge-ghost text-[0.6rem]">Queued</span>
        </div>
        <div class="text-sm whitespace-pre-line break-words text-base-content/60">
          {String.trim(@message.content)}
        </div>
      </div>
    </div>
    """
  end
  ```

- [ ] ⏸ **REFACTOR**: Ensure visual consistency with existing user message styling in template (same avatar, layout pattern, but dimmed)

### Phase 2 Validation

- [ ] ⏸ All component tests pass: `mix test apps/agents_web/test/live/sessions/components/session_components_test.exs`
- [ ] ⏸ No boundary violations

---

## Phase 3: LiveView State Management — Add queued_messages assign and populate on send

> Modify `index.ex` to track queued messages and render them in the template. Integration tests via ConnCase.

### Step 3.1: Add `queued_messages` to assign_session_state and verify initialization

- [ ] ⏸ **RED**: Add test to `apps/agents_web/test/live/sessions/index_test.exs`
  ```
  describe "queued messages" do
    test "initializes with empty queued_messages on mount"
  end
  ```
  - Mount the LiveView, verify no queued message indicators are rendered

- [ ] ⏸ **GREEN**: Modify `apps/agents_web/lib/live/sessions/index.ex`
  - Add `queued_messages: []` to `assign_session_state/1`
  - This automatically covers mount, new_session, select_session, view_task (they all call `assign_session_state`)

- [ ] ⏸ **REFACTOR**: Verify all paths that call `assign_session_state` now implicitly reset queued_messages

### Step 3.2: Populate queued_messages on send_message_to_running_task

- [ ] ⏸ **RED**: Add test to `apps/agents_web/test/live/sessions/index_test.exs`
  ```
  describe "queued messages" do
    test "sending message while task is running shows queued message in output"
    test "queued message displays with 'Queued' indicator"
    test "form is cleared after sending queued message"
    test "multiple queued messages are shown in order"
  end
  ```
  - Create a running task fixture
  - Mount LiveView, submit instruction via form
  - Since `Sessions.send_message/2` makes an HTTP call to opencode (which won't be available in test), we need to mock/stub this. Use `Mox` or test the socket assign logic directly.
  - **Testing strategy**: Use `send(lv.pid, ...)` pattern — but `send_message_to_running_task` is called from `handle_event`, so we need to either:
    - a) Mock `Sessions.send_message/2` to return `:ok` (preferred)
    - b) Test at the unit level with a fake socket
  - Assert the queued message appears in the rendered HTML with "Queued" indicator
  - Assert the form instruction field is empty after submit

- [ ] ⏸ **GREEN**: Modify `apps/agents_web/lib/live/sessions/index.ex`
  - Modify `send_message_to_running_task/2`:
    ```elixir
    defp send_message_to_running_task(socket, instruction) do
      case Sessions.send_message(socket.assigns.current_task.id, instruction) do
        :ok ->
          queued_msg = %{
            id: Ecto.UUID.generate(),
            content: instruction,
            queued_at: DateTime.utc_now()
          }

          {:noreply,
           socket
           |> assign(:queued_messages, socket.assigns.queued_messages ++ [queued_msg])
           |> assign(:form, to_form(%{"instruction" => ""}))}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    end
    ```

- [ ] ⏸ **REFACTOR**: Clean up

### Step 3.3: Render queued messages in template

- [ ] ⏸ **RED**: Tests from Step 3.2 should now assert the template rendering (already covered)

- [ ] ⏸ **GREEN**: Modify `apps/agents_web/lib/live/sessions/index.html.heex`
  - After the `@output_parts` section and before the question card, add:
    ```heex
    <%!-- Queued messages (pending delivery to agent) --%>
    <%= for msg <- @queued_messages do %>
      <.queued_message message={msg} />
    <% end %>
    ```
  - Place this between the `output_parts` rendering block and the `question_card`

- [ ] ⏸ **REFACTOR**: Verify visual positioning — queued messages should appear after assistant output but before any pending question

### Phase 3 Validation

- [ ] ⏸ All index tests pass: `mix test apps/agents_web/test/live/sessions/index_test.exs`
- [ ] ⏸ No boundary violations

---

## Phase 4: Cleanup — Clear queued messages on terminal events (except cancel)

> When the task completes, fails, or the session changes, queued messages must be cleared. Cancelled tasks preserve queued messages so the user can resume with them.

### Step 4.1: Clear queued messages on task completion/failure

- [x] **RED**: Add tests to `apps/agents_web/test/live/sessions/index_test.exs`
  ```
  describe "queued messages — cleanup on terminal status" do
    test "queued messages are cleared when task_status_changed to completed"
    test "queued messages are cleared when task_status_changed to failed"
    test "queued messages are NOT cleared when task_status_changed to cancelled"
  end
  ```
  - Setup: create a running task, mount LiveView, inject a queued message into assigns via `send(lv.pid, ...)`
  - Send `{:task_status_changed, task.id, "completed"}` message
  - Assert queued messages section is no longer rendered
  - Send `{:task_status_changed, task.id, "cancelled"}` message
  - Assert queued messages are still visible

- [x] **GREEN**: Modify `apps/agents_web/lib/live/sessions/index.ex`
  - In the `handle_info({:task_status_changed, ...})` handler, clear queued messages only for `"completed"` and `"failed"` (NOT `"cancelled"`):
    ```elixir
    socket =
      cond do
        status in ["completed", "failed"] ->
          socket
          |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
          |> assign(:pending_question, nil)
          |> assign(:queued_messages, [])

        status == "cancelled" ->
          socket
          |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
          |> assign(:pending_question, nil)

        true ->
          socket
      end
    ```

- [x] **REFACTOR**: Clean up

### Step 4.2: Verify queued messages persist on cancel_task

- [x] **RED**: Add test to `apps/agents_web/test/live/sessions/index_test.exs`
  ```
  describe "queued messages — persist on cancel" do
    test "queued messages are NOT cleared when user cancels task"
  end
  ```

- [x] **GREEN**: No implementation change needed in `do_cancel_task/2` — queued_messages are left untouched by default.

- [x] **REFACTOR**: Verify the test passes without any cancel-related clearing logic

### Step 4.3: Clear queued messages on session transitions (already covered by assign_session_state)

- [ ] ⏸ **RED**: Add tests to `apps/agents_web/test/live/sessions/index_test.exs`
  ```
  describe "queued messages — cleanup on session transitions" do
    test "queued messages are cleared when selecting a different session"
    test "queued messages are cleared when clicking New Session"
    test "queued messages are cleared when deleting the active session"
  end
  ```

- [ ] ⏸ **GREEN**: Already handled — all these paths call `assign_session_state/1` which includes `queued_messages: []`. Verify tests pass.

- [ ] ⏸ **REFACTOR**: Confirm no edge cases missed

### Step 4.4: Queued message cleanup via EventProcessor on user message.updated

- [ ] ⏸ **RED**: Add integration test to `apps/agents_web/test/live/sessions/index_test.exs`
  ```
  describe "queued messages — cleanup via event processor" do
    test "queued message is removed when matching user message.updated event arrives"
    test "non-matching user message.updated does not remove queued messages"
  end
  ```
  - Inject queued messages into the LiveView process
  - Send `{:task_event, task.id, message_updated_event}` with `role=user`
  - Assert the matching queued message is removed from the rendered HTML

- [ ] ⏸ **GREEN**: This should work with the EventProcessor changes from Phase 1. Verify end-to-end flow.

- [ ] ⏸ **REFACTOR**: Clean up

### Phase 4 Validation

- [ ] ⏸ All index tests pass: `mix test apps/agents_web/test/live/sessions/index_test.exs`
- [ ] ⏸ All event processor tests pass: `mix test apps/agents_web/test/live/sessions/event_processor_test.exs`
- [ ] ⏸ No boundary violations

---

## Phase 5: BDD Feature File

> Add browser-level scenarios to the existing sessions feature file for queued message visibility.

### Step 5.1: Add queued message scenarios

- [ ] ⏸ **RED/GREEN**: Add scenarios to `apps/agents_web/test/features/sessions/sessions.browser.feature`
  ```gherkin
  # ---------------------------------------------------------------------------
  # Queued Messages (#255)
  # ---------------------------------------------------------------------------
  # NOTE: Full end-to-end testing of queued messages requires a running
  # opencode container (Docker). The template rendering and visual
  # indicators are verified by unit/integration tests in:
  #   - apps/agents_web/test/live/sessions/index_test.exs
  #   - apps/agents_web/test/live/sessions/components/session_components_test.exs
  #   - apps/agents_web/test/live/sessions/event_processor_test.exs
  #
  # Browser feature scenarios below verify the input form behavior that's
  # testable without Docker.

  Scenario: Input form placeholder indicates queuing when task is running
    # This scenario validates the existing placeholder text behavior
    # which is already implemented but not yet covered by BDD tests.
    # Actual queued message display requires a running container.
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click the "New Session" button
    And I wait for 1 seconds
    Then "textarea#session-instruction" should exist
    And "textarea#session-instruction[placeholder='Describe the coding task...']" should exist
  ```

- [ ] ⏸ **REFACTOR**: Review feature file for completeness

### Phase 5 Validation

- [ ] ⏸ Feature file syntax is valid
- [ ] ⏸ Scenarios cover the testable aspects of the feature

---

## Pre-Commit Checkpoint

- [ ] ⏸ `mix test apps/agents_web/` — all tests pass
- [ ] ⏸ `mix precommit` — formatting, credo, boundary checks pass
- [ ] ⏸ `mix boundary` — no violations

---

## Testing Strategy

- **Total estimated tests**: ~18-22
- **Distribution**:
  - EventProcessor unit tests (Phase 1): ~5 tests
  - Component unit tests (Phase 2): ~6 tests
  - LiveView integration tests (Phase 3-4): ~10-12 tests
  - BDD scenarios (Phase 5): ~1 scenario (limited by Docker requirement)

### Test Pyramid Rationale

- **Most tests at unit level**: EventProcessor cleanup logic and component rendering are pure/deterministic — fast, no DB needed
- **Integration tests for state flow**: LiveView ConnCase tests verify the full assign → template → event pipeline
- **BDD minimal**: Queued message display requires a running container to trigger `send_message_to_running_task`, which limits what browser tests can cover. The critical paths are validated by unit and integration tests.

### Key Testing Challenges

1. **Mocking `Sessions.send_message/2`**: The function makes an HTTP call to opencode. In integration tests, we may need to:
   - Use Mox to mock the Sessions facade
   - Or test at a lower level by directly manipulating assigns via `send/2`
   - Recommended: Use `send/2` to simulate the queued_messages assign state, since the actual `Sessions.send_message` behavior is already tested in the `agents` app

2. **EventProcessor content matching**: The `message.updated` event for user messages may have different content formats. Need to verify what opencode sends back (text content in `info.content` or `info.parts[0].text`) and match accordingly.

---

## Implementation Notes

### Queued Message Data Structure

```elixir
%{
  id: "uuid-string",           # Ecto.UUID.generate()
  content: "user instruction", # trimmed string
  queued_at: ~U[2026-03-01 ...]  # DateTime.utc_now()
}
```

### Content Matching Strategy for Cleanup

When `message.updated` with `role=user` arrives from opencode, the event typically includes the message content. We match by comparing:
- Trimmed content of the queued message
- Against the trimmed content from the event's info payload

If the event format doesn't include content directly, we fall back to removing the oldest queued message (FIFO assumption — opencode processes messages in order).

### Template Insertion Position

Queued messages render:
1. **After** the output_parts section (assistant messages, tool calls)
2. **Before** the pending question card
3. **Within** the `#session-log` scrollable container

This positions them at the "end of conversation so far" — visually indicating where the user's message sits in the queue.
