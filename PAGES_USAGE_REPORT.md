# Comprehensive Pages Context Usage Report

## Overview
This report documents all usage of the `Jarga.Pages` context throughout the codebase. When renaming `Pages → Documents`, these files will need updates.

---

## 1. Core Pages Context Module Files

### Domain & Infrastructure Layer
- `/home/swq/Documents/github/jargav3/lib/jarga/pages.ex` (main context module)
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/page.ex` (schema: "pages" table)
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/page_component.ex` (schema: "page_components" table)
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/queries.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/domain/slug_generator.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/infrastructure/page_repository.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/infrastructure/authorization_repository.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/services/component_loader.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/services/notification_service.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/services/pub_sub_notifier.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/use_cases/use_case.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/use_cases/create_page.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/use_cases/update_page.ex`
- `/home/swq/Documents/github/jargav3/lib/jarga/pages/use_cases/delete_page.ex`

---

## 2. LiveView Files Using Pages

### 1. `/home/swq/Documents/github/jargav3/lib/jarga_web/live/app_live/pages/show.ex`
**Alias:** `alias Jarga.{Pages, Notes, Workspaces, Projects, Documents}`
**Functions Called:**
- `Pages.get_page_note(page)` (line 23)
- `Pages.update_page(user, page.id, %{title: title})` (line 178)
- `Pages.update_page(user, page.id, %{is_pinned: !page.is_pinned})` (line 202)
- `Pages.update_page(user, page.id, %{is_public: !page.is_public})` (line 219)
- `Pages.delete_page(user, page.id)` (line 243)
- `Pages.get_page_by_slug(user, workspace_id, slug)` (line 533)

**PubSub Usage:**
- Subscribes to: `"page:#{page.id}"` (line 27)
- Broadcasts to: `"page:#{page.id}"` (line 76, 142)
- Receives info messages:
  - `{:yjs_update, ...}` (line 301)
  - `{:awareness_update, ...}` (line 307)
  - `{:page_visibility_changed, page_id, is_public}` (line 313)
  - `{:page_pinned_changed, page_id, is_pinned}` (line 324)
  - `{:page_title_changed, page_id, title}` (line 335)

**HTML Elements:**
- Title input hook: `phx-hook="PageTitleInput"`
- Editor hook: `phx-hook="MilkdownEditor"`
- Events: `toggle_pin`, `toggle_public`, `delete_page`, `update_title`

### 2. `/home/swq/Documents/github/jargav3/lib/jarga_web/live/app_live/projects/show.ex`
**Alias:** `alias Jarga.{Workspaces, Projects, Pages}`
**Functions Called:**
- `Pages.list_pages_for_project(user, workspace.id, project.id)` (line 175)
- `Pages.create_page(user, workspace_id, %{title: title, project_id: project_id})` (line 217)
- `Pages.list_pages_for_project(user, workspace_id, project_id)` (line 220)

**Events:**
- `show_page_modal`, `hide_page_modal`, `create_page`, `delete_project`

**HTML Elements:**
- Modal for creating pages with form field `@page_form[:title]`
- Page card display with `data-page-id={page.id}`

### 3. `/home/swq/Documents/github/jargav3/lib/jarga_web/live/app_live/workspaces/show.ex`
**Alias:** `alias Jarga.{Workspaces, Projects, Pages}`
**Functions Called:**
- `Pages.list_pages_for_workspace(user, workspace.id)` (line 470)
- `Pages.create_page(user, workspace_id, %{title: title})` (line 518)
- `Pages.list_pages_for_workspace(user, workspace_id)` (line 521)
- `Pages.list_pages_for_workspace(user, workspace_id)` (line 743)

**Events:**
- `show_page_modal`, `hide_page_modal`, `create_page`

**HTML Elements:**
- Modal for creating pages
- Page card display with `data-page-id={page.id}`

---

## 3. Permissions Helper

**File:** `/home/swq/Documents/github/jargav3/lib/jarga_web/live/permissions_helper.ex`

**Page-related functions** (lines 79-147):
- `can_create_page?(member)` - checks `:create_page` permission
- `can_edit_page?(member, page, current_user)` - checks `:edit_page` permission
- `can_delete_page?(member, page, current_user)` - checks `:delete_page` permission
- `can_pin_page?(member, page, current_user)` - checks `:pin_page` permission

---

## 4. Database Layer (Ecto Schemas)

### Pages Table
**File:** `/home/swq/Documents/github/jargav3/lib/jarga/pages/page.ex`

**Schema:**
```
fields: title, slug, is_public, is_pinned
belongs_to: user, workspace, project, created_by_user
has_many: page_components
timestamps: inserted_at, updated_at
```

**Constraints:**
- Unique constraint: `pages_workspace_id_slug_index` (workspace_id + slug)

### PageComponents Join Table
**File:** `/home/swq/Documents/github/jargav3/lib/jarga/pages/page_component.ex`

**Schema:**
```
fields: component_type, component_id (UUID), position
belongs_to: page (Jarga.Pages.Page)
timestamps: inserted_at, updated_at
```

**Constraints:**
- Foreign key: page_id
- Unique constraint: (page_id + component_type + component_id)

---

## 5. Database Migrations

### Migration Files (all reference "pages" and "page_components" tables):
1. `/home/swq/Documents/github/jargav3/priv/repo/migrations/20251103145700_create_initial_schema.exs`
2. `/home/swq/Documents/github/jargav3/priv/repo/migrations/20251104185349_add_note_id_to_pages.exs`
3. `/home/swq/Documents/github/jargav3/priv/repo/migrations/20251104190644_add_slug_to_pages.exs`
4. `/home/swq/Documents/github/jargav3/priv/repo/migrations/20251104191324_backfill_page_slugs.exs`
5. `/home/swq/Documents/github/jargav3/priv/repo/migrations/20251104193607_create_page_components.exs`
6. `/home/swq/Documents/github/jargav3/priv/repo/migrations/20251104193825_migrate_existing_pages_to_components.exs`
7. `/home/swq/Documents/github/jargav3/priv/repo/migrations/20251104194031_remove_note_id_from_pages.exs`
8. `/home/swq/Documents/github/jargav3/priv/repo/migrations/20251105005400_add_performance_indexes_to_pages.exs`

---

## 6. Routes

**File:** `/home/swq/Documents/github/jargav3/lib/jarga_web/router.ex`

**Route Definition:**
```elixir
live "/workspaces/:workspace_slug/pages/:page_slug", AppLive.Pages.Show, :show
```

**Path Parameters:**
- `:workspace_slug` - workspace identifier
- `:page_slug` - page identifier

---

## 7. JavaScript/Frontend Files

### 1. `/home/swq/Documents/github/jargav3/assets/js/page_hooks.js`
**Exports Two Hooks:**

**MilkdownEditor Hook:**
- Handles editor lifecycle and collaboration
- Sends events:
  - `yjs_update` - collaboration updates
  - `awareness_update` - cursor awareness
  - `force_save` - on visibility change/unload
- Receives events:
  - `yjs_update` - remote edits
  - `awareness_update` - remote cursors
  - `insert-text` - from chat panel
  - `ai_chunk`, `ai_done`, `ai_error` - AI responses

**PageTitleInput Hook:**
- Handles page title input keyboard interactions
- Enter key: blur and autosave, focus editor
- Escape key: cancel editing

### 2. `/home/swq/Documents/github/jargav3/assets/js/page_hooks.test.js`
Test file for page hooks

---

## 8. Page Save Debouncer (Infrastructure)

### 1. `/home/swq/Documents/github/jargav3/lib/jarga_web/live/page_save_debouncer.ex`
**Purpose:** Debounces page saves to prevent race conditions

**Key Features:**
- Per-page GenServer process
- Debounces database writes (configurable, default 2 seconds)
- Broadcasts immediately, saves delayed
- Ensures no data loss on termination

**Functions:**
- `request_save(page_id, user, note_id, yjs_state, markdown)` - Request a debounced save

### 2. `/home/swq/Documents/github/jargav3/lib/jarga_web/live/page_save_debouncer_supervisor.ex`
**Purpose:** DynamicSupervisor for PageSaveDebouncer processes

---

## 9. PubSub Notifications

**File:** `/home/swq/Documents/github/jargav3/lib/jarga/pages/services/pub_sub_notifier.ex`

**Broadcasting Channels:**
- `"workspace:#{workspace_id}"` - workspace-level updates
- `"page:#{page_id}"` - page-specific updates

**Events Broadcast:**
1. `{:page_visibility_changed, page_id, is_public}` - page visibility changed
2. `{:page_pinned_changed, page_id, is_pinned}` - page pinned status changed
3. `{:page_title_changed, page_id, title}` - page title changed

---

## 10. Test Files Using Pages

### Unit/Integration Tests:
1. `/home/swq/Documents/github/jargav3/test/jarga/pages_test.exs`
2. `/home/swq/Documents/github/jargav3/test/jarga/pages/page_test.exs`
3. `/home/swq/Documents/github/jargav3/test/jarga/pages/page_component_test.exs`
4. `/home/swq/Documents/github/jargav3/test/jarga/pages/queries_test.exs`
5. `/home/swq/Documents/github/jargav3/test/jarga/pages/domain/slug_generator_test.exs`
6. `/home/swq/Documents/github/jargav3/test/jarga/pages/infrastructure/authorization_repository_test.exs`
7. `/home/swq/Documents/github/jargav3/test/jarga/pages/infrastructure/page_repository_test.exs`
8. `/home/swq/Documents/github/jargav3/test/jarga/pages/services/component_loader_test.exs`
9. `/home/swq/Documents/github/jargav3/test/jarga/pages/services/notification_service_test.exs`
10. `/home/swq/Documents/github/jargav3/test/jarga/pages/services/pub_sub_notifier_test.exs`
11. `/home/swq/Documents/github/jargav3/test/jarga/pages/use_cases/create_page_test.exs`

### LiveView Tests:
1. `/home/swq/Documents/github/jargav3/test/jarga_web/live/app_live/pages_test.exs`
2. `/home/swq/Documents/github/jargav3/test/jarga_web/live/app_live/pages/show_ai_test.exs`
3. `/home/swq/Documents/github/jargav3/test/jarga_web/live/app_live/projects/show_test.exs`
4. `/home/swq/Documents/github/jargav3/test/jarga_web/live/app_live/workspaces/show_test.exs`
5. `/home/swq/Documents/github/jargav3/test/jarga_web/live/app_live/workspaces/show_test.exs`
6. `/home/swq/Documents/github/jargav3/test/jarga_web/live/chat_live/persistence_and_context_test.exs`
7. `/home/swq/Documents/github/jargav3/test/jarga_web/live/chat_live/panel_test.exs`

### Cross-Context Tests:
1. `/home/swq/Documents/github/jargav3/test/jarga/notes/infrastructure/authorization_repository_test.exs` - Uses Pages for testing notes auth

### Test Fixtures:
- `/home/swq/Documents/github/jargav3/test/support/fixtures/pages_fixtures.ex`

---

## 11. Cross-Context References

### Notes Context References Pages:
**File:** `/home/swq/Documents/github/jargav3/lib/jarga/notes/infrastructure/authorization_repository.ex`
```elixir
join: pc in Jarga.Pages.PageComponent
join: p in Jarga.Pages.Page
```

### Documents Context Uses Pages:
**File:** `/home/swq/Documents/github/jargav3/lib/jarga/documents/use_cases/ai_query.ex`
- Uses pages context indirectly through app_live/pages/show.ex

---

## 12. Web Layer References

### PageController
**File:** `/home/swq/Documents/github/jargav3/lib/jarga_web/controllers/page_controller.ex`
- Home page controller (not Pages context related - general page controller)

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Core context modules | 14 |
| LiveView files using Pages | 3 |
| Database migration files | 8 |
| JavaScript hook files | 2 |
| Infrastructure files | 2 |
| Test files | 18+ |
| Routes referencing pages | 1 |
| PubSub channels | 2 |
| Page functions exported | 8 |
| Permissions functions | 5 |

---

## Key Renaming Considerations

### 1. Module Names
- `Jarga.Pages` → `Jarga.Documents`
- `Jarga.Pages.Page` → `Jarga.Documents.Document`
- `Jarga.Pages.PageComponent` → `Jarga.Documents.DocumentComponent`
- Submodules follow same pattern

### 2. Database Tables
- `pages` → `documents`
- `page_components` → `document_components`
- Update all migrations

### 3. Function Names
Consider renaming for consistency:
- `get_page_*` → `get_document_*`
- `list_pages_*` → `list_documents_*`
- `create_page` → `create_document`
- `update_page` → `update_document`
- `delete_page` → `delete_document`

### 4. Routes
- `/pages/:page_slug` → `/documents/:document_slug`
- Path parameters: `:page_slug` → `:document_slug`

### 5. PubSub Topics
- `page:#{page_id}` → `document:#{document_id}`
- `page_visibility_changed` → `document_visibility_changed`
- `page_pinned_changed` → `document_pinned_changed`
- `page_title_changed` → `document_title_changed`

### 6. HTML/Template
- Hooks: `PageTitleInput` → `DocumentTitleInput`, `MilkdownEditor` → `MilkdownEditor` (keep generic)
- Events: `create_page` → `create_document`, `toggle_pin` → `toggle_pin` (contextual)
- Data attributes: `data-page-id` → `data-document-id`

### 7. JavaScript
- File: `page_hooks.js` → `document_hooks.js`
- Debouncer: `PageSaveDebouncer` → `DocumentSaveDebouncer`
- Registry: `PageSaveDebouncerRegistry` → `DocumentSaveDebouncerRegistry`

### 8. Permissions
- `:create_page` → `:create_document`
- `:edit_page` → `:edit_document`
- `:delete_page` → `:delete_document`
- `:pin_page` → `:pin_document`
