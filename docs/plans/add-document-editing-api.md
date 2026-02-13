# Plan: Add Document Editing to `jarga_api`

## Current State

The API supports **creating** (`POST`) and **reading** (`GET`) documents but has **no update/edit endpoint**. The domain layer (`jarga`) already has a fully implemented `UpdateDocument` use case (`apps/jarga/lib/documents/application/use_cases/update_document.ex`) and facade function (`Jarga.Documents.update_document/4`) for document metadata (title, visibility, pinned). However, note content lives in a separate `notes` table and `NoteRepository` currently only supports `get_by_id/1` and `create/1` — it has no `update` function. The `NoteSchema.changeset/2` already supports casting `note_content`, so the schema layer is ready.

This plan covers both document metadata updates **and** note content updates through the API, with **optimistic concurrency control** via content hashing to prevent lost updates.

## What Needs to Be Built

Following the existing patterns exactly (Clean Architecture, DI via opts, boundary rules), you need these new pieces.

### Prerequisites in the Domain Layer (`jarga` app)

Before the API layer work, three additions are needed in the domain:

#### 0a. `NoteRepository.update/2`

**File:** `apps/jarga/lib/documents/notes/infrastructure/repositories/note_repository.ex`

Add an `update/2` function to complement the existing `get_by_id/1` and `create/1`:

```elixir
def update(%NoteSchema{} = note, attrs) do
  note
  |> NoteSchema.changeset(attrs)
  |> Repo.update()
end
```

`NoteSchema.changeset/2` already casts `note_content`, so no schema changes are needed.

#### 0b. `ContentHash` domain module

**File:** `apps/jarga/lib/documents/notes/domain/content_hash.ex`

A pure domain module (no dependencies) that computes a deterministic hash of note content. This lives in the domain layer because it represents a domain concept — the identity of a content version.

```elixir
defmodule Jarga.Documents.Notes.Domain.ContentHash do
  @moduledoc """
  Computes a deterministic hash of note content for optimistic concurrency control.

  Used by the API to detect stale writes: clients must provide the hash of the
  content they based their changes on. If it doesn't match the server's current
  content hash, the update is rejected with a conflict response.
  """

  @doc """
  Computes a SHA-256 hex digest of the given content.

  `nil` content is treated as empty string so that a newly created document
  (with no content yet) has a stable, predictable hash.
  """
  @spec compute(String.t() | nil) :: String.t()
  def compute(nil), do: compute("")
  def compute(content) when is_binary(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
```

**Why SHA-256:** It's fast, collision-resistant, and produces a fixed 64-char hex string that's easy to pass in JSON. The hash is computed on-the-fly (not stored) — it's cheap enough that there's no need to add a column.

#### 0c. `Jarga.Documents.update_document_note/2` facade function

**File:** `apps/jarga/lib/documents.ex`

Add a convenience function that fetches a document's note component and updates its content:

```elixir
def update_document_note(%Document{} = document, attrs) do
  note = get_document_note(document)
  NoteRepository.update(note, attrs)
end
```

This keeps the API use case from needing to orchestrate note fetching + updating itself.

---

### 1. API Use Case: `UpdateDocumentViaApi`

**File:** `apps/jarga_api/lib/jarga_api/accounts/application/use_cases/update_document_via_api.ex`

Mirrors `CreateDocumentViaApi` structure:

- **Input:** `user`, `api_key`, `workspace_slug`, `document_slug`, `attrs`, `opts`
- **Steps:**
  1. Fast-fail on nil/empty `workspace_access`
  2. Verify API key access via `ApiKeyScope.includes?/2`
  3. Fetch workspace + member via injected `get_workspace_and_member_by_slug`
  4. Resolve document by slug via injected `get_document_by_slug` (reuse from `GetDocumentViaApi` pattern)
  5. Translate `"visibility"` -> `is_public` (only when `"visibility"` key is present in attrs)
  6. **If `"content"` is provided, require and verify `"content_hash"`:**
     - Extract `"content_hash"` from attrs -- if missing, return `{:error, :content_hash_required}`
     - Fetch the document's current note via injected `get_document_note`
     - Compute hash of current `note_content` via `ContentHash.compute(note.note_content)`
     - Compare provided hash against computed hash
     - If mismatch, return `{:error, :content_conflict, %{content: note.note_content, content_hash: current_hash}}`
  7. Split attrs into two groups:
     - **Document attrs** (whitelist: `title`, `is_public`) -- forwarded to `update_document`
     - **Content attrs** (`content`) -- forwarded to `update_document_note` as `%{note_content: content}`
  8. Call injected `update_document(user, document.id, document_attrs)` for metadata changes
  9. If `"content"` was provided (and hash matched), call injected `update_document_note(document, %{note_content: content})` for note content
  10. Return the updated document
- **Returns:**
  - `{:ok, result_map}` -- success (includes updated content + new `content_hash`)
  - `{:error, :content_hash_required}` -- `content` was provided without `content_hash`
  - `{:error, :content_conflict, conflict_data}` -- hash mismatch; `conflict_data` contains the current `content` and `content_hash` the client should re-base from
  - `{:error, :forbidden | :workspace_not_found | :document_not_found | changeset}`

**Design decision -- visibility default:** Unlike create (which defaults `is_public` to `false`), update should only set `is_public` if `"visibility"` is explicitly provided. Omitting visibility means "don't change it."

**Design decision -- content hash is only required when content is being changed:** If the client only sends `title` or `visibility` (no `"content"` key), no hash is needed and the note is not touched. The hash requirement is scoped strictly to content mutations.

**Design decision -- content updates:** Note content lives in a separate `notes` table, not on the document itself. The use case handles this by splitting the update into two operations: document metadata via the existing `UpdateDocument` domain use case, and note content via the new `update_document_note` facade function. Both are called through injected functions to maintain Clean Architecture boundaries. If only metadata is provided, the note update is skipped. If only content is provided, the document metadata update is skipped (or called with empty attrs, which is a no-op).

**Design decision -- no transactional guarantee across both updates:** The document metadata update and note content update are separate operations. This is acceptable because they are independent resources, and partial failure (e.g., metadata succeeds but content fails) can be retried by the client. If stronger guarantees are needed later, these can be wrapped in an `Ecto.Multi`.

**Design decision -- conflict window:** There is a small TOCTOU window between reading the note to check the hash and writing the updated content. This is acceptable for an API that's used for programmatic updates, not real-time collaboration (which uses Yjs/CRDT over WebSocket). The window is small (single-digit milliseconds) and the consequence of a rare collision is a stale write that can be retried.

---

### 2. Accounts Facade Function

**File:** `apps/jarga_api/lib/jarga_api/accounts.ex`

Add:

```elixir
def update_document_via_api(user, api_key, workspace_slug, document_slug, attrs, opts) do
  UseCases.UpdateDocumentViaApi.execute(user, api_key, workspace_slug, document_slug, attrs, opts)
end
```

---

### 3. Controller Action: `update/2`

**File:** `apps/jarga_api/lib/jarga_api/controllers/document_api_controller.ex`

Add an `update/2` action following the `create/2` pattern:

- Extract `workspace_slug` and `slug` (document slug) from params
- Extract updateable attrs: `Map.take(params, ["title", "content", "content_hash", "visibility"])`
- Wire DI opts:
  - `get_workspace_and_member_by_slug` -> `&Workspaces.get_workspace_and_member_by_slug/2`
  - `get_document_by_slug` -> `&Documents.get_document_by_slug/3`
  - `get_document_note` -> `&Documents.get_document_note/1`
  - `update_document` -> `&Documents.update_document/3` (takes `user, document_id, attrs`)
  - `update_document_note` -> `&Documents.update_document_note/2` (takes `document, attrs`)
- Handle responses:
  - `{:ok, result}` -> `200` with `:updated` render
  - `{:error, %Ecto.Changeset{} = changeset}` -> `422` with `:validation_error`
  - `{:error, :content_hash_required}` -> `422` with error message `"content_hash is required when updating content"`
  - `{:error, :content_conflict, conflict_data}` -> `409 Conflict` with `:content_conflict` render (returns current `content` and `content_hash` so the client can re-base)
  - `{:error, :document_not_found}` -> `404`
  - `{:error, :workspace_not_found}` -> `404`
  - `{:error, :forbidden | :unauthorized}` -> `403`

---

### 4. JSON View: `updated/1`

**File:** `apps/jarga_api/lib/jarga_api/controllers/document_api_json.ex`

Add two new render functions:

**`updated/1`** -- Use the same shape as `show/1` for consistency, plus `content_hash`. After an update, the client wants the full current state so it can use the new `content_hash` for its next update. The use case should return a result map with `title`, `slug`, `content`, `content_hash`, `visibility`, `owner`, `workspace_slug`, and optionally `project_slug`.

**`content_conflict/1`** -- Renders a `409 Conflict` response when the provided `content_hash` doesn't match the server's current content. Returns the current state so the client can re-base:

```json
{
  "error": "content_conflict",
  "message": "Content has been modified since your last read. Re-base your changes from the returned content.",
  "data": {
    "content": "the current note content on the server",
    "content_hash": "abc123...the hash of that content"
  }
}
```

**Also modify `show/1` and `created/1`** to include `content_hash` in their responses. This is how clients obtain the hash they need for subsequent update requests:

- `show/1` -- Add `content_hash` computed from `result.content` via `ContentHash.compute/1`
- `created/1` -- Add `content_hash` (for newly created documents, the content is whatever was passed at creation time, or `nil`; compute the hash from that)

---

### 5. Route

**File:** `apps/jarga_api/lib/jarga_api/router.ex`

Add:

```elixir
patch("/workspaces/:workspace_slug/documents/:slug", DocumentApiController, :update)
```

Use `PATCH` (not `PUT`) since the API supports partial updates -- you can send just `title`, just `visibility`, or both.

---

## Tests Required

### 6. Use Case Unit Tests: `UpdateDocumentViaApiTest`

**File:** `apps/jarga_api/test/jarga_api/accounts/application/use_cases/update_document_via_api_test.exs`

Mirror `CreateDocumentViaApiTest` with mocked functions:

- **Success cases:**
  - Update title only (no `content_hash` needed)
  - Update visibility only (no `content_hash` needed)
  - Update content only with correct `content_hash`
  - Update title + visibility + content together with correct `content_hash`
  - Omitting visibility doesn't change it
  - Omitting content doesn't touch the note and doesn't require `content_hash`
  - Response includes new `content_hash` after successful update
- **Content hash validation cases:**
  - Content provided without `content_hash` -> `{:error, :content_hash_required}`
  - Content provided with wrong `content_hash` -> `{:error, :content_conflict, conflict_data}`
  - Conflict response includes current `content` and correct `content_hash`
  - Hash of `nil` content (empty document) is predictable and stable
- **Forbidden cases:** wrong workspace in API key, nil/empty workspace_access
- **Workspace errors:** not found, unauthorized
- **Document errors:** not found, forbidden (trying to edit another user's private doc)
- **Validation errors:** changeset passthrough (e.g., empty title)
- **Content update errors:** note update failure is propagated
- **Attribute sanitization:** unknown keys filtered out, no injection of `user_id`, `content_hash` not forwarded to domain

### 7. Controller Integration Tests

**File:** `apps/jarga_api/test/jarga_api/controllers/document_api_controller_test.exs`

Add a `describe "PATCH /api/workspaces/:workspace_slug/documents/:slug"` block:

- 200 -- successfully update title (response includes `content_hash`)
- 200 -- successfully update visibility
- 200 -- successfully update content with correct `content_hash`
- 200 -- successfully update title + content together
- 200 -- update with no changes (idempotent)
- 403 -- API key lacks workspace access
- 403 -- trying to edit another user's private document
- 404 -- document not found
- 404 -- workspace not found
- 409 -- content conflict (stale `content_hash`, response includes current content + hash)
- 422 -- validation error (e.g., blank title)
- 422 -- content provided without `content_hash`

### 8. JSON View Unit Tests

**File:** `apps/jarga_api/test/jarga_api/controllers/document_api_json_test.exs`

Add tests for:
- `updated/1` -- renders full document state including `content_hash`
- `content_conflict/1` -- renders conflict response with current content and hash
- Updated `show/1` -- now includes `content_hash`
- Updated `created/1` -- now includes `content_hash`

### 9. BDD Feature Scenarios

**File:** `apps/jarga_api/test/features/documents.feature`

Add scenarios like:

- Scenario: Update a document title via API
- Scenario: Update document visibility via API
- Scenario: Update document content via API with correct content_hash
- Scenario: Update document title and content together via API
- Scenario: Update document content with stale content_hash returns conflict with current state
- Scenario: Update document content without content_hash returns 422
- Scenario: Cannot update another user's private document via API
- Scenario: Update non-existent document returns 404
- Scenario: GET document response includes content_hash

---

## Summary of Files to Create/Modify

**Domain layer (`jarga` app) -- prerequisites:**

| Action     | File                                                                                           |
| ---------- | ---------------------------------------------------------------------------------------------- |
| **Create** | `apps/jarga/lib/documents/notes/domain/content_hash.ex` (pure hash computation module)         |
| **Modify** | `apps/jarga/lib/documents/notes/infrastructure/repositories/note_repository.ex` (add `update/2`) |
| **Modify** | `apps/jarga/lib/documents.ex` (add `update_document_note/2` facade function)                   |
| **Create** | `apps/jarga/test/documents/notes/domain/content_hash_test.exs` (test hash computation)         |
| **Create** | `apps/jarga/test/documents/notes/infrastructure/repositories/note_repository_test.exs` (test `update/2`) |

**API layer (`jarga_api` app):**

| Action     | File                                                                                           |
| ---------- | ---------------------------------------------------------------------------------------------- |
| **Create** | `apps/jarga_api/lib/jarga_api/accounts/application/use_cases/update_document_via_api.ex`       |
| **Modify** | `apps/jarga_api/lib/jarga_api/accounts.ex` (add facade function)                               |
| **Modify** | `apps/jarga_api/lib/jarga_api/controllers/document_api_controller.ex` (add `update/2`)         |
| **Modify** | `apps/jarga_api/lib/jarga_api/controllers/document_api_json.ex` (add `updated/1`, `content_conflict/1`; update `show/1` and `created/1` to include `content_hash`) |
| **Modify** | `apps/jarga_api/lib/jarga_api/router.ex` (add PATCH route)                                     |
| **Create** | `apps/jarga_api/test/jarga_api/accounts/application/use_cases/update_document_via_api_test.exs` |
| **Modify** | `apps/jarga_api/test/jarga_api/controllers/document_api_controller_test.exs` (add update tests; update existing show/create tests for `content_hash`) |
| **Modify** | `apps/jarga_api/test/jarga_api/controllers/document_api_json_test.exs` (add updated/conflict tests; update show/created tests) |
| **Modify** | `apps/jarga_api/test/features/documents.feature` (add BDD scenarios)                           |

## What You Don't Need to Build

- **Domain `UpdateDocument` use case** -- `Jarga.Documents.Application.UseCases.UpdateDocument` already exists and handles authorization, access control, changeset updates, and PubSub notifications for document metadata.
- **Note schema changes** -- `NoteSchema.changeset/2` already casts `note_content`, so no schema modifications are needed.
- **New migrations** -- No database changes needed. Both the `documents` and `notes` tables already have the required columns. The content hash is computed on-the-fly, not stored.
- **Boundary changes** -- `jarga_api` already depends on `Jarga.Documents` which exports what's needed. The new `ContentHash` module is a pure domain module with zero dependencies. The new `update_document_note/2` facade function lives on the existing `Jarga.Documents` context.
- **Stored hash column** -- The hash is computed at read time from `note_content`, not persisted. This avoids a migration and keeps the notes table clean. The computation (SHA-256 of a text string) is negligible.

## Note on Yjs/CRDT Interaction

The `notes` table also has a `yjs_state` binary column used for real-time collaborative editing via WebSocket. The API content update only modifies `note_content` (the plain-text representation) and does **not** touch `yjs_state`. If the document is simultaneously being edited in the collaborative editor, the API-written `note_content` may be overwritten by the next Yjs sync. This is acceptable for API use cases (programmatic content seeding, bulk updates) where real-time collaboration is not active.

The `content_hash` mechanism is designed for API-to-API concurrency (e.g., two scripts updating the same document), not for API-vs-WebSocket coordination. The Yjs CRDT system has its own conflict resolution.

## Client Workflow Example

```
1. GET /api/workspaces/my-ws/documents/my-doc
   Response: { "data": { "content": "Hello world", "content_hash": "a591a6d4...", ... } }

2. Client modifies content locally: "Hello world" -> "Hello universe"

3. PATCH /api/workspaces/my-ws/documents/my-doc
   Body: { "content": "Hello universe", "content_hash": "a591a6d4..." }
   Response (200): { "data": { "content": "Hello universe", "content_hash": "f3b1c8d2...", ... } }

   Client stores new content_hash for next update.

4. Meanwhile, another client updates content to "Goodbye world"

5. First client tries another update:
   PATCH /api/workspaces/my-ws/documents/my-doc
   Body: { "content": "Hello galaxy", "content_hash": "f3b1c8d2..." }  <- stale hash
   Response (409): {
     "error": "content_conflict",
     "message": "Content has been modified since your last read...",
     "data": { "content": "Goodbye world", "content_hash": "e8b7c1a3..." }
   }

   Client must re-base changes from the returned content and retry.
```
