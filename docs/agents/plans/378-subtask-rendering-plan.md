# Feature: #378 — Render subtask/subagent invocations as forked conversation cards

## Overview

OpenCode SDK subtask (subagent) prompts are incorrectly rendered as "You" messages in the session UI. When the main agent uses the Task tool to delegate work to a subagent, the SDK emits a `message.part.updated` event with `part.type = "subtask"` containing agent metadata. This part is currently ignored (falls through the catch-all). The subsequent `message.updated` with `role: "user"` and `message.part.updated` with `type: "text"` for the same messageID then render as a user bubble, confusing the user.

**Fix**: Detect subtask parts, track their messageIDs, and render them as collapsible "subagent fork" cards instead of user messages. Both the TaskRunner (DB cache layer) and EventProcessor (LiveView layer) need parallel `subtask_message_ids` tracking.

## UI Strategy
- **LiveView coverage**: 100%
- **TypeScript needed**: None

## Affected Boundaries
- **Owning app**: `agents` (domain — TaskRunner state/caching) and `agents_web` (interface — EventProcessor + components)
- **Repo**: `Agents.Repo` (no migrations needed — this is a state/rendering change, not a schema change)
- **Migrations**: None
- **Feature files**: `apps/agents_web/test/features/` (if BDD added later)
- **Primary context**: `Agents.Sessions` (TaskRunner infrastructure) and `AgentsWeb.SessionsLive` (EventProcessor + components)
- **Dependencies**: None — contained within existing modules
- **Exported schemas**: None
- **New context needed?**: No — this is a bug fix within existing bounded contexts

## Architecture Notes

This change is a **pure rendering/caching fix** — no domain entities, no policies, no use cases, no migrations. The work is split across two layers:

1. **Infrastructure (TaskRunner)**: Add `subtask_message_ids` MapSet to state, track subtask parts for DB caching, suppress user message tracking for subtask messageIDs
2. **Interface (EventProcessor + SessionComponents)**: Add `subtask_message_ids` to LiveView assigns, process subtask parts into `{:subtask, ...}` output tuples, render as collapsible cards, handle streaming/frozen states

Since the affected functions are all within existing modules and follow established patterns (parallel to `user_message_ids` tracking), this maps to the existing architecture without new modules.

---

## Phase 1: Domain + Application

**Skipped** — no domain entities, policies, or use cases are needed. This is a rendering/caching bug fix.

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### Step 1: EventProcessor — subtask part detection and output tuple

This is the core logic: when a `message.part.updated` with `part.type = "subtask"` arrives, record the messageID in `subtask_message_ids` and create a `{:subtask, id, detail}` tuple in output_parts.

- [ ] ⏸ **RED**: Write test in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - New describe block: `"process_event/2 — message.part.updated (subtask)"`
  - Test 1: Subtask part event creates `{:subtask, id, detail}` in output_parts with `:running` status
    - Event: `%{"type" => "message.part.updated", "properties" => %{"part" => %{"type" => "subtask", "messageID" => "msg-sub-1", "id" => "sub-1", "sessionID" => "sess-sub", "prompt" => "Explore the codebase", "description" => "Research spike", "agent" => "explore"}}}`
    - Assert: `output_parts` contains `{:subtask, "subtask-msg-sub-1", %{agent: "explore", description: "Research spike", prompt: "Explore the codebase", status: :running}}`
  - Test 2: Subtask part event adds messageID to `subtask_message_ids` assign
    - Assert: `MapSet.member?(result.assigns.subtask_message_ids, "msg-sub-1")`
  - Test 3: Subtask part with `messageId` (lower-camel) variant also works
  - Test 4: Subtask part with optional `model` and `command` fields still creates correct tuple (fields ignored for display)
- [ ] ⏸ **GREEN**: Implement new `process_event/2` clause in `apps/agents_web/lib/live/sessions/event_processor.ex`
  - Add clause BEFORE the text part handler (line 73) to match `%{"type" => "message.part.updated", "properties" => %{"part" => %{"type" => "subtask"} = part}}`
  - Extract `messageID` via `SdkFieldResolver.resolve_message_id(part)` (or `part["messageID"] || part["messageId"]`)
  - Add messageID to `socket.assigns.subtask_message_ids` MapSet
  - Create `{:subtask, "subtask-#{msg_id}", %{agent: agent, description: description, prompt: prompt, status: :running}}` tuple
  - Upsert into output_parts
- [ ] ⏸ **REFACTOR**: Extract subtask detail building into a private helper function

### Step 2: EventProcessor — suppress user message tracking for subtask messageIDs

When a `message.updated` with `role: "user"` arrives for a messageID already in `subtask_message_ids`, skip adding it to `user_message_ids` and skip queued message dedup.

- [ ] ⏸ **RED**: Write test in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - New describe block: `"process_event/2 — message.updated (user) subtask suppression"`
  - Test 1: User `message.updated` for a subtask messageID does NOT add to `user_message_ids`
    - Setup: socket with `subtask_message_ids: MapSet.new(["msg-sub-1"])`
    - Event: `%{"type" => "message.updated", "properties" => %{"info" => %{"role" => "user", "id" => "msg-sub-1"}}}`
    - Assert: `msg-sub-1` NOT in `result.assigns.user_message_ids`
  - Test 2: User `message.updated` for a subtask messageID does NOT trigger queued message dedup
    - Setup: socket with `subtask_message_ids: MapSet.new(["msg-sub-1"]), queued_messages: [%{id: "q-1", content: "...", queued_at: ~U[...]}]`
    - Assert: queued_messages unchanged
  - Test 3: Normal user `message.updated` (not in subtask_message_ids) still tracks correctly (regression)
- [ ] ⏸ **GREEN**: Modify `process_event/2` for `message.updated` user clause in `apps/agents_web/lib/live/sessions/event_processor.ex`
  - At the top of the `role: "user"` handler (line 49-70), check if the messageID is in `socket.assigns.subtask_message_ids`
  - If so, return socket unchanged (skip user_message_ids tracking AND queued message dedup)
- [ ] ⏸ **REFACTOR**: Clean up guard logic

### Step 3: EventProcessor — suppress text parts for subtask messageIDs

Text parts whose messageID is in `subtask_message_ids` should NOT be rendered as user bubbles or assistant text. The subtask card already shows the prompt.

- [ ] ⏸ **RED**: Write test in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - New describe block: `"process_event/2 — message.part.updated (text) subtask suppression"`
  - Test 1: Text part for a subtask messageID is suppressed (not added to output_parts)
    - Setup: socket with `subtask_message_ids: MapSet.new(["msg-sub-1"])` and `user_message_ids: MapSet.new()`
    - Event: text part with `messageID: "msg-sub-1"` and text "Explore the codebase"
    - Assert: output_parts is empty (text was suppressed)
  - Test 2: Text part for a normal messageID still renders (regression)
  - Test 3: Text part for a user messageID still routes to user message caching (regression)
- [ ] ⏸ **GREEN**: Modify `process_event/2` for text parts in `apps/agents_web/lib/live/sessions/event_processor.ex`
  - In the text part handler (line 73-88), after checking `user_message_part?`, also check `subtask_message_part?`
  - New private function `subtask_message_part?(part, socket)` — checks if `part["messageID"] || part["messageId"]` is in `socket.assigns.subtask_message_ids`
  - If subtask message part, return socket unchanged (suppress the text)
- [ ] ⏸ **REFACTOR**: Clean up, consider extracting shared message-id-lookup logic

### Step 4: EventProcessor — decode_cached_output for subtask entries

When restoring cached output from DB, subtask entries need to decode back into `{:subtask, ...}` tuples.

- [ ] ⏸ **RED**: Write test in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - In existing `"decode_cached_output/1"` describe block, add:
  - Test 1: Decodes subtask cache entry into `{:subtask, id, detail}` tuple with `:done` status
    - Input: `Jason.encode!([%{"type" => "subtask", "id" => "subtask-msg-1", "agent" => "explore", "description" => "Research spike", "prompt" => "Explore the codebase", "status" => "running"}])`
    - Assert: `[{:subtask, "subtask-msg-1", %{agent: "explore", description: "Research spike", prompt: "Explore the codebase", status: :done}}]`
    - Note: cached subtask status is always decoded as `:done` (same pattern as cached tool status)
- [ ] ⏸ **GREEN**: Add `decode_output_part/1` clause in `apps/agents_web/lib/live/sessions/event_processor.ex`
  - Match `%{"type" => "subtask", "id" => id, "agent" => agent, "description" => desc, "prompt" => prompt}`
  - Return `{:subtask, id, %{agent: agent, description: desc, prompt: prompt, status: :done}}`
  - Status is always `:done` when decoded from cache (same rationale as `safe_cached_tool_status`)
- [ ] ⏸ **REFACTOR**: Clean up

### Step 5: EventProcessor — streaming/frozen state management for subtask parts

`has_streaming_parts?/1` and `freeze_streaming/1` need to handle `{:subtask, ...}` tuples.

- [ ] ⏸ **RED**: Write test in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - In `"has_streaming_parts?/1"` describe block, add:
  - Test 1: Returns true when there are running subtask parts
    - Input: `[{:subtask, "sub-1", %{status: :running}}]`
    - Assert: `true`
  - Test 2: Returns false when subtask is done
    - Input: `[{:subtask, "sub-1", %{status: :done}}]`
    - Assert: `false`
  - In `"freeze_streaming/1"` describe block, add:
  - Test 3: Freezes running subtask parts to done
    - Input: `[{:subtask, "sub-1", %{agent: "explore", description: "d", prompt: "p", status: :running}}]`
    - Assert: `[{:subtask, "sub-1", %{agent: "explore", description: "d", prompt: "p", status: :done}}]`
  - Test 4: Leaves done subtask parts unchanged
- [ ] ⏸ **GREEN**: Modify `has_streaming_parts?/1` and `freeze_streaming/1` in `apps/agents_web/lib/live/sessions/event_processor.ex`
  - `has_streaming_parts?`: Add clause `{:subtask, _, %{status: :running}} -> true`
  - `freeze_streaming`: Add clause `{:subtask, id, detail} -> {:subtask, id, %{detail | status: :done}}`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 6: LiveView assigns — add subtask_message_ids

Add `subtask_message_ids: MapSet.new()` to the session state assigns so EventProcessor can use it.

- [ ] ⏸ **RED**: This is a simple assign addition — verified implicitly by Step 1-3 tests running against a socket with `subtask_message_ids` in assigns. No separate test file needed.
- [ ] ⏸ **GREEN**: Modify `assign_session_state/1` in `apps/agents_web/lib/live/sessions/index.ex`
  - Add `subtask_message_ids: MapSet.new()` to the assign list (line 1367-1382)
- [ ] ⏸ **REFACTOR**: Clean up

### Step 7: SessionComponents — subtask card rendering

Add a new `chat_part/1` clause for `{:subtask, id, detail}` tuples that renders a collapsible "subagent fork" card.

- [ ] ⏸ **RED**: Write test in `apps/agents_web/test/live/sessions/session_components_test.exs` (new file)
  - Test 1: Subtask part renders with agent name and description
    - Render `<.chat_part part={part} />` with `part = {:subtask, "sub-1", %{agent: "explore", description: "Research spike", prompt: "Explore the codebase", status: :running}}`
    - Assert: rendered HTML contains "explore", "Research spike", a spinner/running indicator
    - Assert: rendered HTML contains data-testid="subtask-sub-1"
  - Test 2: Done subtask renders with checkmark instead of spinner
    - Same part with `status: :done`
    - Assert: no spinner, has check icon
  - Test 3: Subtask card is collapsible with prompt text in body
    - Assert: `<details>` element with prompt text inside
- [ ] ⏸ **GREEN**: Add `chat_part/1` clause in `apps/agents_web/lib/live/sessions/components/session_components.ex`
  - Place BEFORE the catch-all assistant clause (line 343)
  - Match `%{part: {:subtask, id, detail}}`
  - Render a card with:
    - Icon: `hero-arrow-path-rounded-square` (fork icon)
    - Header: "Subtask: {detail.agent}" with description text
    - Status: spinner for `:running`, checkmark for `:done`
    - Collapsible `<details>` body showing the prompt text
    - `data-testid={"subtask-#{id}"}` for testing
- [ ] ⏸ **REFACTOR**: Extract icon/status helpers, ensure consistent styling with tool cards

### Step 8: TaskRunner — subtask_message_ids state tracking and DB caching

Add `subtask_message_ids` MapSet to TaskRunner state. When a subtask part arrives, record the messageID and cache a subtask entry in `output_parts`. Suppress user message tracking for subtask messageIDs.

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - Since TaskRunner functions are private and the GenServer lifecycle is heavy, test the pure logic by extracting to testable functions OR testing through the GenServer `handle_info`. Given the complexity of the existing test setup, the recommended approach is to test via EventProcessor (the public interface) and add targeted TaskRunner state assertions.
  - Add a new describe block: `"subtask part handling"`
  - The cleanest approach: extract the subtask detection/caching logic into testable pure functions that are tested independently, then integration-test through EventProcessor.
  - **Alternative minimal approach** (recommended given test complexity): Test that the DB-cached output correctly round-trips through EventProcessor's `decode_cached_output`. This validates the cache format without needing a full GenServer harness.
  - Test 1: Subtask cache entry format matches expected JSON structure
    - Build the expected entry: `%{"type" => "subtask", "id" => "subtask-msg-1", "agent" => "explore", "description" => "Research spike", "prompt" => "Explore the codebase", "status" => "running"}`
    - Encode as JSON, decode via `EventProcessor.decode_cached_output/1`
    - Assert produces correct `{:subtask, ...}` tuple
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - **State struct** (line 33): Add `subtask_message_ids: MapSet.new()` field
  - **`handle_info({:opencode_event, event}, state)`** (line 458-476): Restructure the event flow:
    ```
    state = track_subtask_message_id(event, state)
    state = track_user_message_id(event, state)
    cond do
      subtask_part?(event) -> {:noreply, cache_subtask_part(event, state)}
      user_message_part?(event, state) -> {:noreply, cache_user_message_part(event, state)}
      true -> handle_sdk_result(event, state)
    end
    ```
  - **New function `track_subtask_message_id/2`**:
    - Match `%{"type" => "message.part.updated", "properties" => %{"part" => %{"type" => "subtask"} = part}}`
    - Extract messageID from `part["messageID"] || part["messageId"]`
    - Add to `state.subtask_message_ids` MapSet
    - Return updated state
    - Catch-all returns state unchanged
  - **New function `subtask_part?/1`**:
    - Match `%{"type" => "message.part.updated", "properties" => %{"part" => %{"type" => "subtask"}}}`
    - Return true/false
  - **New function `cache_subtask_part/2`**:
    - Extract agent, description, prompt from the part
    - Build cache entry: `%{"type" => "subtask", "id" => "subtask-#{msg_id}", "agent" => agent, "description" => description, "prompt" => prompt, "status" => "running"}`
    - Upsert into `state.output_parts`
  - **Modify `track_user_message_id/2`** (line 665-681):
    - In the `role: "user"` clause, check if the messageID is in `state.subtask_message_ids`
    - If so, skip adding to `user_message_ids` (return state unchanged)
  - **Modify `user_message_part?/2`** (line 683-705):
    - Also return false if the messageID is in `state.subtask_message_ids`
- [ ] ⏸ **REFACTOR**: Clean up, ensure consistent naming with existing patterns

### Phase 2 Validation
- [ ] ⏸ All EventProcessor tests pass: `mix test apps/agents_web/test/live/sessions/event_processor_test.exs`
- [ ] ⏸ All SessionComponents tests pass: `mix test apps/agents_web/test/live/sessions/session_components_test.exs`
- [ ] ⏸ All TaskRunner tests pass: `mix test apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
- [ ] ⏸ No boundary violations: `mix boundary`
- [ ] ⏸ Full test suite passes: `mix test`
- [ ] ⏸ Pre-commit checks pass: `mix precommit`

---

## Testing Strategy

- **Total estimated tests**: 16-18
- **Distribution**:
  - Domain: 0 (no domain changes)
  - Application: 0 (no use case changes)
  - Infrastructure (TaskRunner): 1 (round-trip cache format test)
  - Interface (EventProcessor): 12-14 tests across 5 describe blocks
  - Interface (SessionComponents): 3 tests for rendering

### Test File Summary

| Test File | New Tests | Type |
|-----------|-----------|------|
| `apps/agents_web/test/live/sessions/event_processor_test.exs` | ~14 | ExUnit.Case (async, no DB) |
| `apps/agents_web/test/live/sessions/session_components_test.exs` | ~3 | ExUnit.Case (component render) |
| `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs` | ~1 | Cache format round-trip |

### Event Flow After Fix

```
SDK emits message.part.updated (type: "subtask", messageID: "X")
  → TaskRunner: track_subtask_message_id → adds "X" to subtask_message_ids
  → TaskRunner: cache_subtask_part → adds subtask entry to output_parts
  → EventProcessor: process_event → creates {:subtask, ...} tuple, adds to subtask_message_ids
  → SessionComponents: chat_part → renders collapsible fork card

SDK emits message.updated (role: "user", id: "X")
  → TaskRunner: track_user_message_id → skips (X in subtask_message_ids)
  → EventProcessor: process_event → skips (X in subtask_message_ids)

SDK emits message.part.updated (type: "text", messageID: "X")
  → TaskRunner: user_message_part? → false (X in subtask_message_ids)
  → TaskRunner: falls through to handle_sdk_event (text caching)
  → EventProcessor: text handler → suppressed (X in subtask_message_ids)
```

### DB Cache Format

```json
{"type": "subtask", "id": "subtask-msg-X", "agent": "explore", "description": "Research spike", "prompt": "Explore the codebase", "status": "running"}
```

### Output Part Tuple

```elixir
{:subtask, "subtask-msg-X", %{agent: "explore", description: "Research spike", prompt: "Explore the codebase", status: :running | :done}}
```

---

## Implementation Order

1. **Step 6** — Add `subtask_message_ids` assign (trivial, unblocks all other steps)
2. **Step 1** — EventProcessor subtask part detection (core logic)
3. **Step 2** — EventProcessor user message suppression
4. **Step 3** — EventProcessor text part suppression
5. **Step 4** — EventProcessor decode_cached_output
6. **Step 5** — EventProcessor streaming/frozen state
7. **Step 7** — SessionComponents rendering
8. **Step 8** — TaskRunner state tracking and caching

Steps 1-6 can be done in a single commit. Step 7 (rendering) can be a second commit. Step 8 (TaskRunner) can be a third commit.
