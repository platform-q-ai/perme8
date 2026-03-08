# Feature: #383 — Fix agent sessions: isolate parent/child session events to prevent conversation halting and incorrect message attribution

## Overview

When an opencode session spawns a subagent via the Task tool, the child session's SSE events are processed as if they belong to the parent session. This causes two bugs:

1. **Conversation halts** — the `session.status → idle` transition from the child session is misinterpreted as the parent session completing, stopping the parent agent mid-conversation.
2. **Incorrect message attribution** — the child session's `role: "user"` message (the subagent's prompt) is treated as a parent session user message, appearing as "You" in the UI instead of being nested under the subagent card.

The root cause is that the opencode SDK's global SSE stream (`GET /event`) emits events from ALL sessions (parent + children) on a single stream, and neither TaskRunner (server-side) nor EventProcessor (client-side) filter events by session ID.

**This is a bug fix within existing code — no new domain entities, policies, use cases, or migrations are needed.**

## UI Strategy
- **LiveView coverage**: 100%
- **TypeScript needed**: None

## Affected Boundaries
- **Owning app**: `agents` (domain — TaskRunner infrastructure) and `agents_web` (interface — EventProcessor, LiveView)
- **Repo**: `Agents.Repo` (no schema changes — this is a state/event-processing fix)
- **Migrations**: None
- **Feature files**: `apps/agents_web/test/features/` (if BDD added later)
- **Primary context**: `Agents.Sessions` (TaskRunner infrastructure) and `AgentsWeb.SessionsLive` (EventProcessor)
- **Dependencies**: None — contained within existing modules
- **Exported schemas**: None
- **New context needed?**: No — bug fix within existing bounded contexts

## Architecture Notes

### Event Flow (Current — Broken)

```
SSE Stream (GET /event) → {:opencode_event, event}
  ↓
TaskRunner.handle_info/2 — processes ALL events regardless of session ID
  ↓
PubSub broadcast → {:task_event, task_id, event}
  ↓
LiveView.handle_info/2 → EventProcessor.process_event/2
  ↓
LiveView: maybe_sync_status_from_session_event/3 — reacts to ANY session.status idle
```

### Event Flow (Target — Fixed)

```
SSE Stream (GET /event) → {:opencode_event, event}
  ↓
TaskRunner.handle_info/2 — FILTERS by session ID
  ├── Parent session events → process normally (output cache, status transitions)
  ├── Known child session events → route to child session handler
  │   ├── Track child session activity for subtask card updates
  │   ├── On child idle → update subtask status to :done, do NOT trigger task completion
  │   └── Skip user message tracking (already handled by subtask_message_ids)
  └── Unknown session events → log + skip (defensive, covers race conditions)
  ↓
PubSub broadcast → {:task_event, task_id, event} (parent events only, child events broadcast with metadata)
  ↓
LiveView.handle_info/2 → EventProcessor.process_event/2
  ↓
LiveView: maybe_sync_status_from_session_event/3 — only reacts to PARENT session idle
```

### Key Design Decisions

1. **Session ID extraction**: SSE events include `sessionID` in their `properties` map (confirmed by existing code in `permission.asked` and `question.asked` handlers). We'll add `resolve_session_id/1` to `SdkFieldResolver` to centralize extraction.

2. **Child session discovery**: Child session IDs will be discovered via two mechanisms:
   - **Proactive**: When a `message.part.updated` with `type: "subtask"` arrives, the part's `sessionID` field identifies the child session.
   - **Reactive**: Any event with a `sessionID` different from the parent's `session_id` is treated as a child session event.

3. **State tracking**: TaskRunner's existing `subtask_message_ids` MapSet is already dead code that never fires. We'll repurpose the child session tracking approach by adding `child_session_ids` to the state struct.

4. **Backward compatibility**: The SSE subscription remains global (`GET /event`). Filtering is purely client-side in TaskRunner and EventProcessor.

5. **Multiple concurrent subagents**: The `child_session_ids` MapSet supports tracking multiple child sessions simultaneously.

6. **Event ordering race condition**: A child session event may arrive before the subtask part that identifies it. We handle this by treating any unknown session ID as a potential child session (log + skip output caching, but still broadcast to LiveView).

7. **Backport fix for historical data**: `decode_cached_output/1` will detect the pattern of `type=tool, name=task` followed by `type=user` and re-attribute the user part as a subagent message.

## Open Questions Resolution

1. **SSE event session ID field**: Confirmed — events include `sessionID` in properties (seen in `permission.asked`, `question.asked` handlers). We'll extract it from all events via `SdkFieldResolver.resolve_session_id/1`.

2. **Event ordering**: Handled defensively — unknown session IDs are logged but not processed for output caching. Once the subtask part arrives and registers the child session ID, subsequent events are correctly routed.

3. **Multiple concurrent subagents**: `child_session_ids` is a MapSet supporting multiple child sessions simultaneously.

---

## Phase 1: Domain + Application

**Skipped** — no domain entities, policies, or use cases are needed. This is an infrastructure/interface bug fix.

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### Step 1: SdkFieldResolver — add `resolve_session_id/1`

Centralize session ID extraction from SSE events. Events use `sessionID` or `session_id` in properties.

- [x] **RED**: Write test in `apps/agents_web/test/live/sessions/sdk_field_resolver_test.exs`
  - Test 1: `resolve_session_id/1` returns value from `"sessionID"` key
  - Test 2: `resolve_session_id/1` falls back to `"session_id"` key
  - Test 3: `resolve_session_id/1` returns nil when neither key present
- [x] **GREEN**: Add `resolve_session_id/1` to `apps/agents_web/lib/live/sessions/sdk_field_resolver.ex`
  ```elixir
  @spec resolve_session_id(map()) :: String.t() | nil
  def resolve_session_id(map) do
    map["sessionID"] || map["session_id"]
  end
  ```
- [x] **REFACTOR**: None needed — single-line function

### Step 2: TaskRunner — add `child_session_ids` to state and session ID filtering in `handle_info/2`

The core fix. Filter SSE events by session ID in `handle_info({:opencode_event, event}, state)`. Only parent session events are processed for output caching and status transitions.

- [x] **RED**: Write tests in `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - New describe block: `"session event isolation"`
  - **Test 1: Parent session event is processed normally**
    - Setup: TaskRunner state with `session_id: "parent-sess-1"`, inject a parent session event with `"sessionID" => "parent-sess-1"`, `"type" => "message.part.updated"` (text part)
    - Assert: event is broadcast via PubSub AND cached in output_parts
  - **Test 2: Child session `session.status → idle` does NOT trigger task completion**
    - Setup: TaskRunner state with `session_id: "parent-sess-1"`, `was_running: true`, `child_session_ids: MapSet.new(["child-sess-1"])`
    - Send: `%{"type" => "session.status", "properties" => %{"sessionID" => "child-sess-1", "status" => %{"type" => "idle"}}}`
    - Assert: TaskRunner remains alive (NOT stopped), state unchanged for `was_running`
  - **Test 3: Child session event is broadcast via PubSub (for LiveView rendering) but NOT cached in output_parts**
    - Setup: TaskRunner state with `session_id: "parent-sess-1"`, `child_session_ids: MapSet.new(["child-sess-1"])`
    - Send child session text event with `"sessionID" => "child-sess-1"`
    - Assert: PubSub broadcast received, but state.output_parts unchanged
  - **Test 4: Subtask part event registers child session ID**
    - Send: `%{"type" => "message.part.updated", "properties" => %{"part" => %{"type" => "subtask", "sessionID" => "child-sess-1", ...}}}`
    - Assert: `"child-sess-1"` added to `state.child_session_ids`
  - **Test 5: Event with unknown session ID (not parent, not known child) is skipped for caching**
    - Send event with `"sessionID" => "unknown-sess"` that is NOT the parent
    - Assert: output_parts unchanged, no crash
  - **Test 6: Event with NO sessionID is treated as parent session (backward compat)**
    - Send event without `sessionID` in properties
    - Assert: processed normally (cached in output_parts)
  - **Test 7: Child session `session.status → idle` updates matching subtask part status to "done"**
    - Setup: state with subtask part `%{"type" => "subtask", "id" => "subtask-msg-1", "status" => "running"}` in output_parts, and `child_session_ids` containing the child session ID with a mapping to the subtask ID
    - Send: `%{"type" => "session.status", "properties" => %{"sessionID" => "child-sess-1", "status" => %{"type" => "idle"}}}`
    - Assert: The subtask part in output_parts has `"status" => "done"`
- [x] **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - **State struct**: Add `child_session_ids: MapSet.new()` field (line ~67)
  - **`handle_info({:opencode_event, event}, state)`** (lines 460-485): Add session ID filtering at the top of the function:
    ```elixir
    def handle_info({:opencode_event, event}, state) do
      event_session_id = extract_event_session_id(event)

      cond do
        # No session ID in event or matches parent → process normally
        is_nil(event_session_id) or event_session_id == state.session_id ->
          process_parent_session_event(event, state)

        # Known child session → route to child handler
        MapSet.member?(state.child_session_ids, event_session_id) ->
          process_child_session_event(event, event_session_id, state)

        # Unknown session → log and skip caching, still broadcast
        true ->
          Logger.debug("TaskRunner: event from unknown session #{event_session_id}, skipping")
          broadcast_event(event, state)
          {:noreply, state}
      end
    end
    ```
  - **New `process_parent_session_event/2`**: Extract current handle_info body into this function
  - **New `process_child_session_event/3`**: Broadcast to PubSub only (for LiveView rendering), handle `session.status → idle` to mark subtask as done, skip output caching
  - **Modify `track_subtask_message_id/2`**: Also extract `sessionID` from subtask part and add to `child_session_ids`
  - **New `extract_event_session_id/1`**: Extract session ID from event properties
    ```elixir
    defp extract_event_session_id(%{"properties" => %{"sessionID" => id}}) when is_binary(id), do: id
    defp extract_event_session_id(%{"properties" => %{"session_id" => id}}) when is_binary(id), do: id
    defp extract_event_session_id(%{"properties" => %{"part" => %{"sessionID" => id}}}) when is_binary(id), do: id
    defp extract_event_session_id(_), do: nil
    ```
  - **Modify child session idle handler**: When child session goes idle, find the matching subtask in output_parts and set its status to "done"
- [x] **REFACTOR**: Extract `broadcast_event/2` helper, clean up the split between parent/child processing

### Step 3: TaskRunner — `handle_sdk_event` session status isolation

The `handle_sdk_event/2` for `session.status` currently reacts to ANY session's idle transition. This function is only called for parent session events after Step 2's filtering, but we add a defensive guard as defense-in-depth.

- [x] **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - New describe block: `"handle_sdk_event session.status isolation"`
  - **Test 1: Parent session running → idle triggers :completed** (existing behavior, ensure not broken)
    - State: `was_running: true, session_id: "parent-sess"`
    - Event: `session.status` with `"sessionID" => "parent-sess"` and `status.type == "idle"`
    - Assert: returns `{:completed, state}`
  - **Test 2: session.status idle without prior running state returns :continue** (existing behavior)
    - State: `was_running: false`
    - Assert: returns `{:continue, state}`
- [x] **GREEN**: No changes needed in `handle_sdk_event/2` itself — the filtering in Step 2 ensures only parent events reach this function. The existing logic is correct once parent/child are separated.
- [x] **REFACTOR**: Add a comment documenting that this function is only called for parent session events (after Step 2's filtering)

### Step 4: TaskRunner — `cache_user_message_part/2` session isolation

After Step 2, child session events are routed to `process_child_session_event/3` which skips output caching, so `cache_user_message_part/2` is never called for child session user messages. No code change needed here, but we need a test to verify the overall behavior.

- [x] **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - **Test 1: Child session user message is NOT cached as a user message part**
    - Setup: state with `session_id: "parent-sess"`, `child_session_ids: MapSet.new(["child-sess"])`
    - Send: `message.updated` with `role: "user"` and `sessionID: "child-sess"`
    - Assert: output_parts does not contain a `"type" => "user"` entry for this message
  - **Test 2: Parent session user message IS cached correctly (regression)**
    - Send: `message.updated` with `role: "user"` and `sessionID: "parent-sess"` followed by a text part
    - Assert: output_parts contains the user entry
- [x] **GREEN**: Already handled by Step 2's session filtering — no additional code changes
- [x] **REFACTOR**: None needed

### Step 5: EventProcessor — session ID filtering for LiveView events

The EventProcessor receives events via PubSub `{:task_event, task_id, event}`. After Step 2, the TaskRunner broadcasts all events (parent + child) to PubSub, but child events now need to be handled differently in the EventProcessor.

The approach: Add a `parent_session_id` assign to the LiveView socket. EventProcessor checks the event's session ID against this. Parent events process normally. Child events are handled specifically for subtask card updates.

- [x] **RED**: Write tests in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - New describe block: `"process_event/2 — session event isolation"`
  - **Test 1: Parent session event processes normally**
    - Socket: `parent_session_id: "parent-sess"`, `child_session_ids: MapSet.new()`
    - Event: text part with no sessionID (backward compat)
    - Assert: output_parts updated
  - **Test 2: Child session `message.updated` with `role: "user"` does NOT add to `user_message_ids`**
    - Socket: `parent_session_id: "parent-sess"`, `child_session_ids: MapSet.new(["child-sess"])`
    - Event: `message.updated` with `role: "user"` and `sessionID: "child-sess"`
    - Assert: `user_message_ids` unchanged
  - **Test 3: Child session text part does NOT add to output_parts**
    - Socket: `parent_session_id: "parent-sess"`, `child_session_ids: MapSet.new(["child-sess"])`
    - Event: `message.part.updated` text with `sessionID: "child-sess"` in properties
    - Assert: output_parts unchanged
  - **Test 4: Child session tool event does NOT add to output_parts**
    - Socket: `parent_session_id: "parent-sess"`, `child_session_ids: MapSet.new(["child-sess"])`
    - Event: `message.part.updated` tool with `sessionID: "child-sess"` in properties
    - Assert: output_parts unchanged
  - **Test 5: Event with unknown session ID is processed normally (backward compat)**
    - Socket: `parent_session_id: nil` (not yet set)
    - Event: text part with any sessionID
    - Assert: output_parts updated (no filtering when parent_session_id is nil)
- [x] **GREEN**: Modify `apps/agents_web/lib/live/sessions/event_processor.ex`
  - Add a new public function `child_session_event?/2` that checks if an event's session ID is in `child_session_ids` and is NOT the parent session ID
  - Add early return in `process_event/2` for child session events:
    ```elixir
    def process_event(event, socket) do
      if child_session_event?(event, socket) do
        process_child_event(event, socket)
      else
        process_parent_event(event, socket)
      end
    end
    ```
  - **Alternative (preferred — less invasive)**: Add a guard function `skip_for_child_session?/2` that returns true if the event's session ID is a known child session. Call it at the top of key processing clauses (message.updated user, message.part.updated text/tool/reasoning) to short-circuit.
  - The subtask `message.part.updated` handler already correctly processes subtask parts regardless of session ID (it's how we discover child sessions).
- [x] **REFACTOR**: Extract session filtering into a reusable private function

### Step 6: LiveView — `maybe_sync_status_from_session_event/3` session filtering

The LiveView `index.ex` has `maybe_sync_status_from_session_event/3` that triggers a task refresh when ANY `session.status → idle` event arrives. This must be filtered to only react to parent session idle events.

- [x] **RED**: Write test (this is tested at the integration level via LiveView tests; document expected behavior)
  - Verify via existing LiveView test or manual verification:
    - Parent session idle → triggers task refresh (existing behavior, keep)
    - Child session idle → does NOT trigger task refresh
  - This is best tested through the EventProcessor/TaskRunner isolation tests above. If the TaskRunner correctly filters events before broadcasting, the LiveView never sees child session status events as parent events.
  - **However**, since TaskRunner broadcasts ALL events to PubSub (both parent and child), we need to add filtering in the LiveView too:
  - **Test**: In `apps/agents_web/test/live/sessions/event_processor_test.exs` (or a new index_test), verify that `maybe_sync_status_from_session_event/3` ignores child session idle events.
  - Actually, the cleanest approach: have TaskRunner annotate child session events with metadata so the LiveView can distinguish them. OR: have TaskRunner NOT broadcast child session status events via the generic `{:task_event, ...}` channel, instead use a separate `{:child_session_event, ...}` message.
- [x] **GREEN**: Modify `apps/agents_web/lib/live/sessions/index.ex` in one of two ways:
  - **Option A (preferred)**: In `maybe_sync_status_from_session_event/3`, extract the event's session ID and compare against the task's known session ID (stored in the current_task assign or a new `parent_session_id` assign). Only trigger refresh for parent session idle.
    ```elixir
    defp maybe_sync_status_from_session_event(socket, %{"type" => "session.status"} = event, task_id) do
      status_type = get_in(event, ["properties", "status", "type"])
      event_session_id = get_in(event, ["properties", "sessionID"])
      parent_session_id = socket.assigns[:parent_session_id]

      case status_type do
        "idle" when is_nil(parent_session_id) or event_session_id == parent_session_id or is_nil(event_session_id) ->
          request_task_refresh(socket, task_id)
        _ ->
          socket
      end
    end
    ```
  - **Option B**: Have TaskRunner only broadcast parent session events via `{:task_event, ...}`. Child events use a separate PubSub topic like `{:child_task_event, ...}`.
- [x] **REFACTOR**: Extract session ID comparison into a helper

### Step 7: LiveView — track `parent_session_id` assign

The LiveView needs to know the parent session ID to filter events. This is set when the task starts running and the session is created.

- [x] **RED**: Verify through existing task lifecycle tests that `parent_session_id` is available
  - When `handle_info({:task_status_changed, task_id, "running"}, socket)` fires, the task has a `session_id` field from the DB
  - Add `parent_session_id` to socket assigns when loading/selecting a task
- [x] **GREEN**: Modify `apps/agents_web/lib/live/sessions/index.ex`
  - When a task is selected or starts running, set `assign(socket, :parent_session_id, task.session_id)`
  - Initialize `parent_session_id: nil` in mount
  - Clear it when the task is deselected
- [x] **REFACTOR**: Ensure `parent_session_id` is consistently set across all task selection paths (direct load, PubSub update, reconnect)

### Step 8: EventProcessor — `decode_cached_output/1` backport fix for historical data

Historical cached output may contain incorrectly attributed user parts (subagent prompts stored as `type: "user"`). Detect the pattern: a `type: "tool"` with `name: "task"` immediately followed by a `type: "user"` part → re-attribute the user part as a `:subtask` tuple.

- [x] **RED**: Write tests in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - New describe block: `"decode_cached_output/1 — backport subagent prompt re-attribution"`
  - **Test 1: user part after task tool is re-attributed as subtask**
    ```elixir
    json = Jason.encode!([
      %{"type" => "tool", "id" => "tool-1", "name" => "task", "status" => "done",
        "input" => %{"prompt" => "Explore the codebase", "description" => "Research spike"}},
      %{"type" => "user", "id" => "user-1", "text" => "Explore the codebase"}
    ])
    parts = EventProcessor.decode_cached_output(json)
    assert [
      {:tool, "tool-1", "task", :done, %{input: %{"prompt" => "Explore the codebase", "description" => "Research spike"}}},
      {:subtask, "user-1", %{agent: "unknown", description: "Research spike", prompt: "Explore the codebase", status: :done}}
    ] = parts
    ```
  - **Test 2: user part NOT after task tool remains as user (regression)**
    ```elixir
    json = Jason.encode!([
      %{"type" => "text", "id" => "text-1", "text" => "Hello"},
      %{"type" => "user", "id" => "user-1", "text" => "Follow-up"}
    ])
    parts = EventProcessor.decode_cached_output(json)
    assert [
      {:text, "text-1", "Hello", :frozen},
      {:user, "user-1", "Follow-up"}
    ] = parts
    ```
  - **Test 3: existing subtask entries still decode correctly (regression)**
    - Same as existing `decode_cached_output/1 — subtask entries` test
  - **Test 4: user part after non-task tool is NOT re-attributed**
    ```elixir
    json = Jason.encode!([
      %{"type" => "tool", "id" => "tool-1", "name" => "read_file", "status" => "done"},
      %{"type" => "user", "id" => "user-1", "text" => "Follow-up question"}
    ])
    parts = EventProcessor.decode_cached_output(json)
    assert Enum.any?(parts, fn {:user, _, _} -> true; _ -> false end)
    ```
- [x] **GREEN**: Modify `decode_cached_output/1` in `apps/agents_web/lib/live/sessions/event_processor.ex`
  - After decoding all parts, post-process the list to detect the `tool(task) → user` adjacency pattern:
    ```elixir
    def decode_cached_output(output) do
      case Jason.decode(output) do
        {:ok, parts} when is_list(parts) ->
          parts
          |> Enum.map(&decode_output_part/1)
          |> Enum.reject(&is_nil/1)
          |> reattribute_subagent_prompts()
        _ ->
          [{:text, "cached-0", output, :frozen}]
      end
    end

    defp reattribute_subagent_prompts(parts) do
      parts
      |> Enum.chunk_every(2, 1, [:end])
      |> Enum.flat_map(fn
        [{:tool, _id, "task", _status, detail} = tool, {:user, user_id, text}] ->
          prompt = get_in_map(detail, :input, "prompt") || text
          description = get_in_map(detail, :input, "description") || ""
          subtask = {:subtask, user_id, %{agent: "unknown", description: description, prompt: prompt, status: :done}}
          [tool, subtask]

        [{:tool, _id, "Task", _status, detail} = tool, {:user, user_id, text}] ->
          # Case-insensitive match for "Task" tool name
          prompt = get_in_map(detail, :input, "prompt") || text
          description = get_in_map(detail, :input, "description") || ""
          subtask = {:subtask, user_id, %{agent: "unknown", description: description, prompt: prompt, status: :done}}
          [tool, subtask]

        [part, _next] ->
          [part]

        [part] ->
          [part]
      end)
    end
    ```
- [x] **REFACTOR**: Extract `task_tool_name?/1` helper for case-insensitive "task" matching

### Step 9: TaskRunner — update subtask part status when child session completes

When a child session's `session.status → idle` event arrives, find the matching subtask part in `output_parts` and set its status to `"done"`. This updates the DB cache so the subtask card shows as complete.

To map child session IDs to subtask part IDs, extend the `child_session_ids` tracking to use a Map instead of a MapSet: `child_session_ids: %{"child-sess-1" => "subtask-msg-1"}`.

- [x] **RED**: Write tests in `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - **Test 1: Child session idle updates subtask part status to "done"**
    - State: output_parts has `%{"type" => "subtask", "id" => "subtask-msg-1", "status" => "running"}`, child_session_ids `%{"child-sess-1" => "subtask-msg-1"}`
    - Event: `session.status` idle from `"child-sess-1"`
    - Assert: output_parts subtask entry has `"status" => "done"`
  - **Test 2: Child session idle for unknown subtask ID is a no-op**
    - State: child_session_ids `%{"child-sess-1" => "subtask-msg-1"}`, but no matching subtask in output_parts
    - Assert: no crash, output_parts unchanged
  - **Test 3: Child session idle broadcasts subtask completion via PubSub**
    - Assert: PubSub receives a message indicating subtask completion (for LiveView to update card)
- [x] **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - Change `child_session_ids` from `MapSet` to `Map` (session_id → subtask_part_id)
  - In `track_subtask_message_id/2`, also record `child_session_ids[subtask_session_id] = subtask_part_id`
  - In `process_child_session_event/3`, when `session.status → idle`:
    ```elixir
    defp process_child_session_event(
           %{"type" => "session.status", "properties" => props},
           child_session_id,
           state
         ) do
      status_type = get_in(props, ["status", "type"]) || props["status"]

      case status_type do
        "idle" ->
          state = mark_subtask_done(state, child_session_id)
          broadcast_event(%{"type" => "session.status", "properties" => props}, state)
          {:noreply, state}
        _ ->
          broadcast_event(%{"type" => "session.status", "properties" => props}, state)
          {:noreply, state}
      end
    end
    ```
  - `mark_subtask_done/2`: Find the subtask part ID from `child_session_ids` map, update its `"status"` to `"done"` in `output_parts`
- [x] **REFACTOR**: Extract subtask completion logic into a well-named helper

### Step 10: EventProcessor — handle child session idle for subtask card update

When the LiveView receives a `session.status → idle` event for a child session, update the matching `:subtask` tuple's status to `:done`.

- [x] **RED**: Write tests in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - New describe block: `"process_event/2 — child session status updates subtask"`
  - **Test 1: Child session idle updates subtask part to :done**
    - Socket: `child_session_ids: MapSet.new(["child-sess-1"])`, `output_parts: [{:subtask, "subtask-msg-1", %{status: :running, agent: "explore", ...}}]`
    - Need a way to map child session ID → subtask part ID. Add `child_session_subtask_map` assign or use the subtask part's metadata.
    - Event: `session.status` idle with `sessionID: "child-sess-1"`
    - Assert: subtask part status updated to `:done`
  - **Test 2: Parent session idle does NOT modify subtask parts**
    - Socket: `parent_session_id: "parent-sess"`, output_parts with running subtask
    - Event: `session.status` idle with `sessionID: "parent-sess"`
    - Assert: subtask parts unchanged (this is the completion path, not subtask update)
- [x] **GREEN**: Modify `apps/agents_web/lib/live/sessions/event_processor.ex`
  - Add handling in the child event processing path to update subtask status
  - Alternatively: the TaskRunner already broadcasts the updated subtask status via a separate PubSub message (e.g., `{:subtask_completed, task_id, subtask_id}`) — the LiveView receives this and updates the subtask card. This is cleaner than having EventProcessor parse session.status events.
- [x] **REFACTOR**: Clean up the child session event handling path

### Step 11: LiveView — add `child_session_ids` assign and propagation

The LiveView needs `child_session_ids` (MapSet) in socket assigns for EventProcessor filtering. This is populated when subtask parts arrive via `process_event/2`.

- [x] **RED**: Verify via existing tests
  - The `subtask_message_ids` assign already exists and is populated by `process_event/2` for subtask parts
  - `child_session_ids` follows the same pattern — populated by subtask part events that include `sessionID`
  - Test: When a subtask part event with `sessionID` arrives, `child_session_ids` is updated
- [x] **GREEN**: Modify `apps/agents_web/lib/live/sessions/index.ex`
  - Add `child_session_ids: MapSet.new()` to the initial assigns in mount
  - Clear it when task is deselected
  - EventProcessor's subtask handler already updates this assign (handled in Step 5)
- [x] **REFACTOR**: Ensure `child_session_ids` is initialized in all mount paths

### Step 12: Remove dead code or add comments

Review and clean up dead code identified in the ticket:

- `subtask_message_ids` in TaskRunner state — repurposed (keep, now correctly tracked)
- `track_subtask_message_id/2` — repurposed (keep, now also tracks child session IDs)
- `subtask_part?/1` — keep (correctly filters subtask parts for caching)
- `cache_subtask_part/2` — keep (correctly caches subtask entries)

- [ ] ⏸ **REFACTOR**: Add documentation comments to clarify the dual role of `track_subtask_message_id/2` (tracks both message IDs and child session IDs)
- [ ] ⏸ **REFACTOR**: Review all remaining dead code and either repurpose with comments or remove

---

## Phase 2 Validation

- [ ] All infrastructure tests pass (`mix test apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`)
- [ ] All interface tests pass (`mix test apps/agents_web/test/live/sessions/event_processor_test.exs`)
- [ ] Existing test suite passes (`mix test`)
- [ ] No boundary violations (`mix boundary`)
- [ ] Pre-commit checks pass (`mix precommit`)

---

## Testing Strategy

### New Tests

| Location | Count | Type |
|----------|-------|------|
| `apps/agents_web/test/live/sessions/sdk_field_resolver_test.exs` | 3 | Unit (async) |
| `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs` | ~12 | DataCase (session isolation) |
| `apps/agents_web/test/live/sessions/event_processor_test.exs` | ~12 | Unit (async) |

### Existing Tests (Regression)

| Location | Count | Notes |
|----------|-------|-------|
| `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs` | 5 | Must still pass |
| `apps/agents_web/test/live/sessions/event_processor_test.exs` | 63 | Must still pass |
| `apps/agents_web/test/live/sessions/event_processor_todo_test.exs` | ? | Must still pass |

### Total estimated new tests: ~27
### Distribution: Infrastructure: ~12, Interface: ~15

---

## Implementation Notes for TDD Agent

### File modification order (bottom-up, dependency order):

1. `apps/agents_web/lib/live/sessions/sdk_field_resolver.ex` — add `resolve_session_id/1`
2. `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex` — session filtering + child tracking
3. `apps/agents_web/lib/live/sessions/event_processor.ex` — child session event handling + backport fix
4. `apps/agents_web/lib/live/sessions/index.ex` — `parent_session_id` + `child_session_ids` assigns + status filtering

### Key state changes:

**TaskRunner state struct additions:**
- `child_session_ids: %{}` (Map: child_session_id → subtask_part_id) — replaces the unused MapSet

**LiveView socket assigns additions:**
- `parent_session_id: nil` — set from task.session_id when task is selected
- `child_session_ids: MapSet.new()` — populated by subtask part events

### Backward compatibility guarantees:
- Events without `sessionID` are treated as parent session events (no behavioral change)
- The global SSE subscription is unchanged
- Cached output from before this fix is rendered correctly via the backport logic in `decode_cached_output/1`
- All existing tests must continue to pass without modification

### Risk areas:
1. **Event ordering**: A child session event arriving before its subtask part will be treated as "unknown session" and logged but not cached. This is safe — the subtask part will arrive shortly after and register the child session ID for subsequent events.
2. **TaskRunner state persistence**: The `child_session_ids` map is in-memory only (not persisted to DB). On TaskRunner restart, child sessions won't be tracked until a new subtask part arrives. This is acceptable because TaskRunner restarts are rare and the worst case is that child events are briefly treated as unknown (logged + skipped).
3. **Multiple concurrent subagents**: The Map-based `child_session_ids` naturally supports multiple concurrent child sessions.
