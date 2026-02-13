# Plan: Yjs Sidecar Service for API-to-Editor Content Sync

## Problem

When document content is updated via the REST API (`PATCH /api/workspaces/:ws/documents/:slug`), connected browser clients using the Yjs collaborative editor have no awareness of the change. The server cannot construct Yjs CRDT updates from markdown — it only relays client-generated binary updates. This means:

1. API-written `note_content` is silently overwritten by the next Yjs save (debounced every 2s)
2. Connected editors continue showing stale content
3. There is no PubSub event for content changes that editors could react to

## Solution

Introduce a **Node.js sidecar process** that speaks Yjs natively. It acts as a bridge between the Elixir application and the Yjs CRDT world — accepting markdown content from the API layer, computing a proper Yjs incremental update, persisting the new `yjs_state`, and broadcasting the update to connected editors through the existing PubSub relay.

## Architecture Overview

```
                                         Phoenix PubSub
                                        ("document:#{id}")
                                              |
  REST API ──> Elixir App ──HTTP──> Yjs Sidecar ──> PubSub broadcast
  (PATCH)      (jarga_api)          (Node.js)        |
                                        |            v
                                        |       LiveView processes
                                        |            |
                                     Postgres     push_event
                                   (yjs_state)       |
                                                  Browsers
                                                 (Yjs editors)
```

### How It Fits Into the Current Architecture

The current Yjs sync flow is **LiveView-mediated**:

```
Browser A -> pushEvent("yjs_update") -> LiveView A
  -> PubSub.broadcast_from("document:#{id}", {:yjs_update, ...})
    -> LiveView B -> push_event("yjs_update") -> Browser B
```

The sidecar introduces a **second ingress point** for Yjs updates — one that originates from the server side rather than a browser client. From the perspective of connected LiveViews and browsers, the sidecar's update looks identical to any other client's update.

---

## What Needs to Be Built

### Phase 1: Sidecar Service

#### 1a. Node.js Service

**Directory:** `services/yjs-sidecar/`

A lightweight HTTP service that:

- Receives a request with the current `yjs_state` (binary), the new markdown content, and a document ID
- Loads the `yjs_state` into a `Y.Doc`
- Computes the diff between the current Yjs content and the new markdown
- Applies the new content to the `Y.Doc`, producing an incremental Yjs update
- Returns the incremental update (base64) and the new complete `yjs_state` (binary)

**Runtime:** Node.js 20.18.0 (already pinned in `.tool-versions`)
**Package manager:** npm (consistent with `apps/jarga_web/assets/`)

**Dependencies:**

| Package | Version | Purpose |
|---------|---------|---------|
| `yjs` | `^13.6.18` | Core CRDT (match existing version) |
| `y-prosemirror` | `^1.3.7` | ProseMirror schema binding (match existing) |
| `y-protocols` | `^1.0.6` | Encoding/decoding protocols (match existing) |
| `lib0` | `^0.2.114` | Utility library (match existing) |
| `@milkdown/kit` or prosemirror packages | Match existing | ProseMirror schema for markdown->Yjs conversion |

**Key design challenge — markdown to Yjs conversion:**

The sidecar needs to convert a markdown string into ProseMirror nodes and then into Yjs XML fragments (since the Yjs doc stores content in a `Y.XmlFragment` named `'prosemirror'`). This requires:

1. Parse markdown to ProseMirror document (using the same schema/parser the editor uses)
2. Replace the content of the `Y.XmlFragment('prosemirror')` in the Y.Doc
3. Encode the resulting Yjs state update

The `y-prosemirror` library provides `prosemirrorJSONToYDoc` and related utilities for this. The critical requirement is that the **ProseMirror schema used by the sidecar must match the editor's schema exactly** — otherwise the Yjs update will be incompatible.

**API endpoint:**

```
POST /apply-content
Content-Type: application/json

{
  "document_id": "uuid",
  "current_yjs_state": "<base64-encoded binary>",
  "new_content": "# Hello\n\nNew markdown content",
  "user_id": "uuid"
}

Response (200):
{
  "incremental_update": "<base64-encoded Yjs update>",
  "new_yjs_state": "<base64-encoded complete state>",
  "new_content_hash": "<sha256 hex of the resulting note_content>"
}

Response (422):
{
  "error": "invalid_yjs_state",
  "message": "Failed to apply Yjs state"
}
```

The sidecar is **stateless** — it does not hold Y.Doc instances in memory between requests. Each request loads state, transforms, and returns the result. This keeps the sidecar simple, horizontally scalable, and crash-safe.

**File structure:**

```
services/yjs-sidecar/
  package.json
  package-lock.json
  tsconfig.json
  src/
    server.ts              # HTTP server (e.g., native Node http or fastify)
    routes/
      apply-content.ts     # POST /apply-content handler
    yjs/
      document-loader.ts   # Load Y.Doc from binary state
      content-applier.ts   # Replace Y.Doc content from markdown
      update-encoder.ts    # Encode incremental update + complete state
    prosemirror/
      schema.ts            # ProseMirror schema (must match editor exactly)
      parser.ts            # Markdown -> ProseMirror doc parser
    health.ts              # GET /health endpoint
  test/
    apply-content.test.ts  # Integration tests
    content-applier.test.ts
    document-loader.test.ts
```

#### 1b. ProseMirror Schema Sharing

The sidecar **must use the exact same ProseMirror schema** as the browser editor. Currently the editor schema comes from Milkdown's commonmark + GFM presets. Two approaches:

**Option A — Extract shared schema (recommended):**
- Create a shared package or module that defines the ProseMirror schema
- Import it in both the browser editor (`apps/jarga_web/assets/`) and the sidecar (`services/yjs-sidecar/`)
- This could be an npm workspace, a symlinked module, or a local package reference

**Option B — Duplicate the schema:**
- Manually replicate the Milkdown schema in the sidecar
- Simpler initially but creates a maintenance burden — any editor plugin change requires updating the sidecar

The recommended approach is to create a shared local package:

```
packages/
  prosemirror-schema/
    package.json
    src/
      index.ts        # Exports the ProseMirror schema + markdown parser
```

Both `apps/jarga_web/assets/package.json` and `services/yjs-sidecar/package.json` reference it:

```json
{
  "dependencies": {
    "@jarga/prosemirror-schema": "file:../../packages/prosemirror-schema"
  }
}
```

---

### Phase 2: Elixir Integration

#### 2a. `YjsSidecar` Client Module

**File:** `apps/jarga/lib/documents/infrastructure/yjs_sidecar_client.ex`

An HTTP client that calls the sidecar's `/apply-content` endpoint. Uses `Finch` (already in the supervision tree as `Jarga.Finch`).

```elixir
defmodule Jarga.Documents.Infrastructure.YjsSidecarClient do
  @moduledoc """
  HTTP client for the Yjs sidecar service.

  Sends markdown content to the sidecar, which computes the Yjs CRDT update
  and returns the incremental update + new complete state.
  """

  @behaviour Jarga.Documents.Application.Behaviours.YjsSidecarBehaviour

  @doc """
  Applies new markdown content to a document's Yjs state.

  Sends the current yjs_state and new content to the sidecar, which returns
  the incremental Yjs update and the new complete state.
  """
  @spec apply_content(String.t(), binary(), String.t(), String.t()) ::
          {:ok, %{incremental_update: binary(), new_yjs_state: binary(), new_content_hash: String.t()}}
          | {:error, term()}
  def apply_content(document_id, current_yjs_state, new_content, user_id) do
    # POST to sidecar /apply-content
    # Encode yjs_state as base64 for JSON transport
    # Decode response base64 fields back to binary
  end
end
```

#### 2b. Behaviour for DI/Testing

**File:** `apps/jarga/lib/documents/application/behaviours/yjs_sidecar_behaviour.ex`

```elixir
defmodule Jarga.Documents.Application.Behaviours.YjsSidecarBehaviour do
  @callback apply_content(String.t(), binary(), String.t(), String.t()) ::
              {:ok, %{incremental_update: binary(), new_yjs_state: binary(), new_content_hash: String.t()}}
              | {:error, term()}
end
```

This allows tests to inject a mock sidecar that returns predetermined Yjs updates.

#### 2c. Updated Content Update Flow

When the API updates document content (via the `UpdateDocumentViaApi` use case), the flow becomes:

```
1. API receives PATCH with content + content_hash
2. Verify content_hash (existing optimistic concurrency check)
3. Fetch current note (with yjs_state)
4. Call YjsSidecarClient.apply_content(doc_id, note.yjs_state, new_content, user_id)
5. Sidecar returns: {incremental_update, new_yjs_state, new_content_hash}
6. Persist to DB: update note with %{note_content: new_content, yjs_state: new_yjs_state}
7. Broadcast incremental_update via PubSub (see 2d)
8. Return success with new_content_hash
```

**File changes:**

- **`Jarga.Documents.update_document_note/2`** — Expand to accept and persist `yjs_state` alongside `note_content`
- **`UpdateDocumentViaApi`** — Add sidecar call step between content_hash verification and note update. Inject sidecar client via opts for testability.

#### 2d. PubSub Broadcast for API-Originated Content Changes

**File:** `apps/jarga/lib/documents/infrastructure/notifiers/pub_sub_notifier.ex`

Add a new notification:

```elixir
def notify_document_content_updated(document_id, incremental_update_base64, user_id) do
  Phoenix.PubSub.broadcast(
    Jarga.PubSub,
    "document:#{document_id}",
    {:yjs_update, %{update: incremental_update_base64, user_id: user_id}}
  )
end
```

This uses the **exact same message format** as the existing LiveView-originated Yjs broadcasts: `{:yjs_update, %{update: base64, user_id: string}}`. Connected LiveView processes already handle this message in `handle_info({:yjs_update, ...})` and forward it to browsers via `push_event`. No changes needed in the LiveView or frontend.

**Add to behaviour:**

```elixir
# In notification_service_behaviour.ex
@callback notify_document_content_updated(String.t(), String.t(), String.t()) :: :ok
```

#### 2e. Update the `UpdateDocumentViaApi` Use Case

The use case gets two new injected dependencies:

```elixir
opts = [
  # ... existing opts ...
  apply_yjs_content: &YjsSidecarClient.apply_content/4,
  notify_content_updated: &PubSubNotifier.notify_document_content_updated/3
]
```

Updated flow when `"content"` is provided:

```
1. Verify content_hash against current note_content (existing)
2. Call apply_yjs_content(document_id, note.yjs_state, new_content, user_id)
3. On success: persist note with %{note_content: new_content, yjs_state: new_yjs_state}
4. Broadcast: notify_content_updated(document_id, incremental_update_base64, user_id)
5. Return {:ok, result} with new content_hash
```

If the sidecar is unavailable, the content update should still succeed (just without Yjs sync). The sidecar call can be wrapped in a try/rescue with a warning log, falling back to the current behavior (update `note_content` only, don't touch `yjs_state`, don't broadcast).

---

### Phase 3: LiveView Adjustments

#### 3a. Handle Yjs State Drift

When a LiveView receives a `{:yjs_update, ...}` that originated from the API (via the sidecar), it's handled identically to any client-originated update — `push_event(socket, "yjs_update", %{update: update})`. The browser applies the incremental update to its local Y.Doc, and `ySyncPlugin` reflects the change in ProseMirror.

**No LiveView changes needed** for the basic flow. The existing `handle_info({:yjs_update, ...})` already handles this.

However, the LiveView's in-memory `note.yjs_state` will be stale after an API update (it only gets updated when a client sends a `yjs_update` event). This is acceptable because:

- The debouncer uses its own latest state (received from the client)
- The `get_current_yjs_state` handler returns from socket assigns, but any connected client that receives the PubSub update will have merged it into their local Y.Doc
- On next client edit, the client sends the merged state to the debouncer

#### 3b. Optional: LiveView State Refresh

For completeness, add a `handle_info` for a new event so the LiveView can update its in-memory state:

```elixir
# Optional: update socket assigns when API changes content
def handle_info({:yjs_state_updated, %{yjs_state: new_state, note_content: new_content}}, socket) do
  note = %{socket.assigns.note | yjs_state: new_state, note_content: new_content}
  {:noreply, assign(socket, :note, note)}
end
```

This is a nice-to-have, not strictly required.

---

### Phase 4: Infrastructure

#### 4a. Docker Compose

**File:** `docker-compose.yml`

Add the sidecar service alongside the existing Postgres services:

```yaml
services:
  postgres_dev:
    # ... existing ...

  postgres_test:
    # ... existing ...

  yjs_sidecar:
    build: ./services/yjs-sidecar
    ports:
      - "4006:4006"
    environment:
      PORT: 4006
      NODE_ENV: development
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4006/health"]
      interval: 10s
      timeout: 5s
      retries: 3
```

#### 4b. Configuration

**File:** `config/config.exs`

```elixir
config :jarga, :yjs_sidecar,
  url: "http://localhost:4006",
  timeout: 5_000
```

**File:** `config/runtime.exs`

```elixir
config :jarga, :yjs_sidecar,
  url: System.get_env("YJS_SIDECAR_URL", "http://localhost:4006"),
  timeout: String.to_integer(System.get_env("YJS_SIDECAR_TIMEOUT", "5000"))
```

**File:** `config/test.exs`

```elixir
config :jarga, :yjs_sidecar,
  url: "http://localhost:4007",    # Test instance or mock
  enabled: false                    # Disable in unit tests, use mock
```

#### 4c. Dev Workflow

Add a Mix task or script to start the sidecar alongside the Phoenix server. Options:

**Option A — Phoenix watcher (recommended for dev):**

```elixir
# config/dev.exs
watchers: [
  esbuild: {Esbuild, :install_and_run, [:jarga, ~w(--sourcemap=inline --watch)]},
  tailwind: {Tailwind, :install_and_run, [:jarga, ~w(--watch)]},
  yjs_sidecar: {System, :cmd, ["node", ["services/yjs-sidecar/dist/server.js"],
    [cd: Path.expand("../services/yjs-sidecar", __DIR__)]]}
]
```

**Option B — Procfile / process manager:**

```
# Procfile.dev
web: mix phx.server
yjs: node services/yjs-sidecar/dist/server.js
```

#### 4d. Port Allocation

| Port | Service | Environment |
|------|---------|-------------|
| 4000 | JargaWeb | dev |
| 4001 | Identity | dev |
| 4002 | JargaWeb | test |
| 4003 | Identity | test |
| 4004 | JargaApi | dev |
| 4005 | JargaApi | test |
| **4006** | **Yjs Sidecar** | **dev** |
| **4007** | **Yjs Sidecar** | **test** |

---

## Tests Required

### Sidecar Tests (Node.js)

**Directory:** `services/yjs-sidecar/test/`

- **Unit: `content-applier.test.ts`**
  - Apply markdown to empty Y.Doc -> produces valid Yjs state
  - Apply markdown to existing Y.Doc -> produces incremental update
  - Incremental update applied to another Y.Doc produces same content
  - Empty content / nil content handling
  - Complex markdown (headings, lists, code blocks, GFM tables)

- **Unit: `document-loader.test.ts`**
  - Load valid yjs_state binary -> Y.Doc with correct content
  - Load empty/nil state -> empty Y.Doc
  - Load corrupted state -> error

- **Integration: `apply-content.test.ts`**
  - POST /apply-content with valid payload -> 200
  - POST /apply-content with invalid yjs_state -> 422
  - Health check endpoint -> 200
  - Large content handling

- **Schema compatibility: `schema-compat.test.ts`**
  - Create Y.Doc from sidecar, open in browser ProseMirror schema -> compatible
  - Round-trip: markdown -> Y.Doc -> markdown preserves content

### Elixir Tests

- **`YjsSidecarClient` unit tests** (with HTTP mock):
  - Successful apply_content call
  - Sidecar unavailable -> error tuple
  - Sidecar returns error -> error tuple
  - Timeout handling

- **Updated `UpdateDocumentViaApi` tests:**
  - Content update with sidecar success -> broadcasts Yjs update
  - Content update with sidecar failure -> graceful degradation (content saved, Yjs not updated, warning logged)
  - Sidecar disabled in config -> skip Yjs update

- **`PubSubNotifier` tests:**
  - `notify_document_content_updated/3` broadcasts correct message format

- **Integration tests:**
  - API content update -> PubSub receives `:yjs_update` message
  - Full round-trip: create doc via API -> update content via API -> GET returns updated content with correct hash

### BDD Scenarios

**File:** `apps/jarga_api/test/features/documents.feature`

- Scenario: Update document content via API syncs to connected editors
- Scenario: API content update when sidecar is unavailable still saves content

---

## Summary of Files to Create/Modify

**New service:**

| Action | File |
|--------|------|
| **Create** | `services/yjs-sidecar/package.json` |
| **Create** | `services/yjs-sidecar/tsconfig.json` |
| **Create** | `services/yjs-sidecar/src/server.ts` |
| **Create** | `services/yjs-sidecar/src/routes/apply-content.ts` |
| **Create** | `services/yjs-sidecar/src/yjs/document-loader.ts` |
| **Create** | `services/yjs-sidecar/src/yjs/content-applier.ts` |
| **Create** | `services/yjs-sidecar/src/yjs/update-encoder.ts` |
| **Create** | `services/yjs-sidecar/src/prosemirror/schema.ts` |
| **Create** | `services/yjs-sidecar/src/prosemirror/parser.ts` |
| **Create** | `services/yjs-sidecar/src/health.ts` |
| **Create** | `services/yjs-sidecar/test/*.test.ts` |

**Shared package (optional but recommended):**

| Action | File |
|--------|------|
| **Create** | `packages/prosemirror-schema/package.json` |
| **Create** | `packages/prosemirror-schema/src/index.ts` |

**Elixir domain layer (`jarga` app):**

| Action | File |
|--------|------|
| **Create** | `apps/jarga/lib/documents/application/behaviours/yjs_sidecar_behaviour.ex` |
| **Create** | `apps/jarga/lib/documents/infrastructure/yjs_sidecar_client.ex` |
| **Modify** | `apps/jarga/lib/documents/application/behaviours/notification_service_behaviour.ex` (add `notify_document_content_updated/3`) |
| **Modify** | `apps/jarga/lib/documents/infrastructure/notifiers/pub_sub_notifier.ex` (add `notify_document_content_updated/3`) |
| **Modify** | `apps/jarga/lib/documents.ex` (expand `update_document_note` to accept yjs_state) |

**API layer (`jarga_api` app):**

| Action | File |
|--------|------|
| **Modify** | `apps/jarga_api/lib/jarga_api/accounts/application/use_cases/update_document_via_api.ex` (add sidecar call + PubSub broadcast) |
| **Modify** | `apps/jarga_api/lib/jarga_api/controllers/document_api_controller.ex` (wire new DI opts) |

**Infrastructure/config:**

| Action | File |
|--------|------|
| **Modify** | `docker-compose.yml` (add yjs_sidecar service) |
| **Modify** | `config/config.exs` (add yjs_sidecar config) |
| **Modify** | `config/runtime.exs` (add yjs_sidecar env vars) |
| **Modify** | `config/test.exs` (add yjs_sidecar test config) |
| **Modify** | `config/dev.exs` (optional: add sidecar watcher) |

**Tests:**

| Action | File |
|--------|------|
| **Create** | `services/yjs-sidecar/test/content-applier.test.ts` |
| **Create** | `services/yjs-sidecar/test/document-loader.test.ts` |
| **Create** | `services/yjs-sidecar/test/apply-content.test.ts` |
| **Create** | `services/yjs-sidecar/test/schema-compat.test.ts` |
| **Create** | `apps/jarga/test/documents/infrastructure/yjs_sidecar_client_test.exs` |
| **Modify** | `apps/jarga_api/test/jarga_api/accounts/application/use_cases/update_document_via_api_test.exs` |

---

## Risks and Mitigations

### Risk: ProseMirror schema drift

The sidecar's ProseMirror schema must exactly match the browser editor's schema. If a Milkdown plugin is added or changed and the sidecar isn't updated, Yjs updates from the sidecar will produce incompatible documents.

**Mitigation:** Extract the ProseMirror schema into a shared `packages/prosemirror-schema` local package used by both the editor and the sidecar. Add a CI check that verifies schema compatibility via round-trip tests.

### Risk: Sidecar availability

If the sidecar is down, API content updates should not fail entirely.

**Mitigation:** Graceful degradation — if the sidecar call fails, save `note_content` without updating `yjs_state` and without broadcasting. Log a warning. Connected editors will be stale until the next browser-initiated edit (which will resync through the normal Yjs flow). The `content_hash` concurrency control still works regardless of sidecar availability.

### Risk: Race condition between sidecar write and browser edit

A browser client could send a Yjs update between the sidecar reading `yjs_state` and writing the new state back.

**Mitigation:** The incremental update from the sidecar is a CRDT operation — when the browser client receives it via PubSub, `Y.applyUpdate` merges it with any concurrent local changes. This is exactly what CRDTs are designed for. The only concern is the `yjs_state` in the database, which could be slightly stale. The next debounced save from any browser client will reconcile this (the client's Y.Doc has merged all updates). This is the same eventual consistency model already in use for browser-to-browser sync.

### Risk: Performance of stateless sidecar

Each request creates a new Y.Doc, loads state, transforms, and discards. For very large documents, loading `yjs_state` (which can grow over time due to CRDT tombstones) could be slow.

**Mitigation:** Monitor response times. If this becomes an issue, options include:
- LRU cache of recently-used Y.Doc instances in the sidecar (keyed by document_id)
- Periodic Yjs state compaction (garbage collection of CRDT tombstones)
- Setting a maximum document size for API content updates

---

## Implementation Order

1. **Phase 1a** — Build the sidecar service with tests (can be done independently)
2. **Phase 1b** — Extract shared ProseMirror schema package
3. **Phase 2a-b** — Elixir HTTP client + behaviour
4. **Phase 2c-e** — Wire into `UpdateDocumentViaApi` use case + PubSub broadcast
5. **Phase 4** — Docker, config, dev workflow
6. **Phase 3** — LiveView adjustments (optional, mostly verifying existing behavior)

Phases 1a and 1b are completely independent of the Elixir work and can be developed in parallel.

---

## What This Does NOT Cover

- **Replacing the LiveView relay with direct WebSocket Yjs sync** (e.g., y-websocket provider) — that's a separate, larger project. The sidecar is additive, not a replacement.
- **Server-initiated content generation** (e.g., AI writing directly into a document) — the existing agent query flow handles this via client-side insertion. The sidecar could enable server-side insertion in the future, but that's out of scope here.
- **Multi-server deployment** — The current PubSub uses PG2 (Erlang distributed). If the app runs on multiple nodes, the sidecar broadcast will reach all nodes through PG2. If the sidecar itself needs to scale horizontally, it remains stateless so multiple instances work fine.
