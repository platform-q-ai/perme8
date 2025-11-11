# Pages → Documents Context Refactoring Checklist

## Quick Reference Checklist

Use this checklist when executing the Pages → Documents rename refactoring.

---

## Phase 1: Core Context Modules

### Module Renames (14 files)
- [ ] `lib/jarga/pages.ex` → `lib/jarga/documents.ex`
- [ ] `lib/jarga/pages/page.ex` → `lib/jarga/documents/document.ex`
- [ ] `lib/jarga/pages/page_component.ex` → `lib/jarga/documents/document_component.ex`
- [ ] `lib/jarga/pages/queries.ex` → `lib/jarga/documents/queries.ex`
- [ ] `lib/jarga/pages/domain/slug_generator.ex` → `lib/jarga/documents/domain/slug_generator.ex`
- [ ] `lib/jarga/pages/infrastructure/page_repository.ex` → `lib/jarga/documents/infrastructure/document_repository.ex`
- [ ] `lib/jarga/pages/infrastructure/authorization_repository.ex` → `lib/jarga/documents/infrastructure/authorization_repository.ex`
- [ ] `lib/jarga/pages/services/component_loader.ex` → `lib/jarga/documents/services/component_loader.ex`
- [ ] `lib/jarga/pages/services/notification_service.ex` → `lib/jarga/documents/services/notification_service.ex`
- [ ] `lib/jarga/pages/services/pub_sub_notifier.ex` → `lib/jarga/documents/services/pub_sub_notifier.ex`
- [ ] `lib/jarga/pages/use_cases/use_case.ex` → `lib/jarga/documents/use_cases/use_case.ex`
- [ ] `lib/jarga/pages/use_cases/create_page.ex` → `lib/jarga/documents/use_cases/create_document.ex`
- [ ] `lib/jarga/pages/use_cases/update_page.ex` → `lib/jarga/documents/use_cases/update_document.ex`
- [ ] `lib/jarga/pages/use_cases/delete_page.ex` → `lib/jarga/documents/use_cases/delete_document.ex`

### Module Content Updates
- [ ] Rename module definitions: `defmodule Jarga.Pages...` → `defmodule Jarga.Documents...`
- [ ] Update schemas: `schema "pages"` → `schema "documents"`
- [ ] Update schemas: `schema "page_components"` → `schema "document_components"`
- [ ] Update associations: `belongs_to(:page, ...)` → `belongs_to(:document, ...)`
- [ ] Update associations: `has_many(:page_components, ...)` → `has_many(:document_components, ...)`

---

## Phase 2: LiveView & Web Layer

### LiveView Files (3 files)
- [ ] Update alias in `lib/jarga_web/live/app_live/pages/show.ex`
  - `alias Jarga.Pages` → `alias Jarga.Documents`
  - Rename file: `pages/show.ex` → `documents/show.ex` (optional, for clarity)
  
- [ ] Update alias in `lib/jarga_web/live/app_live/projects/show.ex`
  - `alias Jarga.Pages` → `alias Jarga.Documents`
  - Replace all: `Pages.list_pages_for_project` → `Documents.list_documents_for_project`
  - Replace all: `Pages.create_page` → `Documents.create_document`

- [ ] Update alias in `lib/jarga_web/live/app_live/workspaces/show.ex`
  - `alias Jarga.Pages` → `alias Jarga.Documents`
  - Replace all: `Pages.list_pages_for_workspace` → `Documents.list_documents_for_workspace`
  - Replace all: `Pages.create_page` → `Documents.create_document`

### HTML/Template Updates (in LiveView files)
- [ ] Update data attributes: `data-page-id` → `data-document-id`
- [ ] Update form field references: `@page_form` → `@document_form`
- [ ] Update variable names: `@pages` → `@documents`, `page` → `document`
- [ ] Update event handlers: 
  - `show_page_modal` → `show_document_modal`
  - `hide_page_modal` → `hide_document_modal`
  - `create_page` → `create_document`
  - `delete_page` → `delete_document`
  - `toggle_pin` (keep) - contextual naming

### Permissions Helper
- [ ] `lib/jarga_web/live/permissions_helper.ex`
  - `can_create_page?` → `can_create_document?`
  - `can_edit_page?` → `can_edit_document?`
  - `can_delete_page?` → `can_delete_document?`
  - `can_pin_page?` → `can_pin_document?`
  - Update PermissionsPolicy calls: `:create_page` → `:create_document`, etc.

---

## Phase 3: Infrastructure

### Page Save Debouncer (2 files)
- [ ] Rename `lib/jarga_web/live/page_save_debouncer.ex` → `lib/jarga_web/live/document_save_debouncer.ex`
  - [ ] Update module name: `PageSaveDebouncer` → `DocumentSaveDebouncer`
  - [ ] Update function: `request_save(page_id, ...)` → `request_save(document_id, ...)`
  - [ ] Update via tuple: `PageSaveDebouncerRegistry` → `DocumentSaveDebouncerRegistry`

- [ ] Update `lib/jarga_web/live/page_save_debouncer_supervisor.ex`
  - [ ] Rename to `document_save_debouncer_supervisor.ex`
  - [ ] Update module name: `PageSaveDebouncerSupervisor` → `DocumentSaveDebouncerSupervisor`
  - [ ] Update child spec references

### JavaScript/Frontend (2 files)
- [ ] Rename `assets/js/page_hooks.js` → `assets/js/document_hooks.js`
  - [ ] Rename hook: `PageTitleInput` → `DocumentTitleInput`
  - [ ] Keep `MilkdownEditor` (generic name, reused)
  - [ ] Update import statements in any using files

- [ ] Update `assets/js/page_hooks.test.js` → `assets/js/document_hooks.test.js`

---

## Phase 4: Routes & PubSub

### Routes
- [ ] `lib/jarga_web/router.ex`
  - Update route: `/workspaces/:workspace_slug/pages/:page_slug` 
  - To: `/workspaces/:workspace_slug/documents/:document_slug`
  - Update live module reference: `AppLive.Pages.Show` → `AppLive.Documents.Show`

### PubSub Channels
- [ ] Update in LiveView files:
  - Subscribe: `"page:#{page.id}"` → `"document:#{document.id}"`
  - Broadcast: `"page:#{page.id}"` → `"document:#{document.id}"`

- [ ] Update in `lib/jarga/documents/services/pub_sub_notifier.ex`:
  - Change topic: `"page:#{page_id}"` → `"document:#{document_id}"`
  - Rename events:
    - `{:page_visibility_changed, ...}` → `{:document_visibility_changed, ...}`
    - `{:page_pinned_changed, ...}` → `{:document_pinned_changed, ...}`
    - `{:page_title_changed, ...}` → `{:document_title_changed, ...}`

- [ ] Update LiveView info handlers:
  - `handle_info({:page_visibility_changed, ...})` → `handle_info({:document_visibility_changed, ...})`
  - `handle_info({:page_pinned_changed, ...})` → `handle_info({:document_pinned_changed, ...})`
  - `handle_info({:page_title_changed, ...})` → `handle_info({:document_title_changed, ...})`

---

## Phase 5: Database Migrations

### Create Migration for Rename (1 new migration)
- [ ] Create new migration file: `priv/repo/migrations/YYYYMMDDHHMMSS_rename_pages_to_documents.exs`
  - [ ] Rename table: `pages` → `documents`
  - [ ] Rename table: `page_components` → `document_components`
  - [ ] Update foreign keys: `page_id` → `document_id`
  - [ ] Update index names: `pages_workspace_id_slug_index` → `documents_workspace_id_slug_index`
  - [ ] Rename constraints: `pages_` prefix → `documents_` prefix

### Existing Migration Updates (update all 8 migration files)
- [ ] Update table name references in all historical migrations
- [ ] Ensure migration compatibility with new names

---

## Phase 6: Cross-Context References

### Notes Context
- [ ] `lib/jarga/notes/infrastructure/authorization_repository.ex`
  - Update joins: 
    - `join: pc in Jarga.Pages.PageComponent` → `join: pc in Jarga.Documents.DocumentComponent`
    - `join: p in Jarga.Pages.Page` → `join: p in Jarga.Documents.Document`

### Documents Context
- [ ] `lib/jarga/documents/use_cases/ai_query.ex`
  - Check for any Pages references and update

---

## Phase 7: Test Files

### Unit & Integration Tests (11 test files)
- [ ] `test/jarga/documents_test.exs` (rename from pages_test.exs)
  - [ ] Update module names in test
  - [ ] Update assertions/expectations

- [ ] `test/jarga/documents/document_test.exs` (rename from page_test.exs)
- [ ] `test/jarga/documents/document_component_test.exs` (rename from page_component_test.exs)
- [ ] `test/jarga/documents/queries_test.exs`
- [ ] `test/jarga/documents/domain/slug_generator_test.exs`
- [ ] `test/jarga/documents/infrastructure/authorization_repository_test.exs`
- [ ] `test/jarga/documents/infrastructure/document_repository_test.exs` (rename from page_repository_test.exs)
- [ ] `test/jarga/documents/services/component_loader_test.exs`
- [ ] `test/jarga/documents/services/notification_service_test.exs`
- [ ] `test/jarga/documents/services/pub_sub_notifier_test.exs`
- [ ] `test/jarga/documents/use_cases/create_document_test.exs` (rename from create_page_test.exs)

### LiveView Tests (7 test files)
- [ ] `test/jarga_web/live/app_live/documents_test.exs` (rename from pages_test.exs)
- [ ] `test/jarga_web/live/app_live/documents/show_ai_test.exs` (rename from pages/show_ai_test.exs)
- [ ] `test/jarga_web/live/app_live/projects/show_test.exs` - update Pages references
- [ ] `test/jarga_web/live/app_live/workspaces/show_test.exs` - update Pages references
- [ ] `test/jarga_web/live/chat_live/persistence_and_context_test.exs` - update Pages references
- [ ] `test/jarga_web/live/chat_live/panel_test.exs` - update Pages references

### Test Fixtures
- [ ] `test/support/fixtures/documents_fixtures.ex` (rename from pages_fixtures.ex)
  - [ ] Update all fixture function names: `page_fixture` → `document_fixture`, etc.
  - [ ] Update attribute names in fixtures

---

## Phase 8: Validation & Cleanup

### Compilation & Tests
- [ ] Run `mix compile` - check for no "forbidden reference" warnings
- [ ] Run `mix test` - ensure all tests pass
- [ ] Run `mix credo` - check code quality
- [ ] Fix any remaining references to old naming

### Search & Replace Verification
- [ ] Global search for remaining `Pages.` references
- [ ] Global search for remaining `:page_` atom references
- [ ] Global search for remaining `page_id` column references (should now be `document_id`)
- [ ] Global search for remaining `/pages/` route references
- [ ] Global search for remaining `page:` PubSub topic references

### Documentation
- [ ] Update CLAUDE.md if Pages context is referenced
- [ ] Update ARCHITECTURE.md if Pages context is documented
- [ ] Update any inline code comments mentioning Pages

---

## Summary Statistics

Total files to modify/rename: 60+

### By Category:
- Context modules: 14 files
- LiveView files: 3 files
- Permissions helper: 1 file
- Infrastructure: 2 files
- JavaScript: 2 files
- Routes: 1 file
- Migrations: 9 files
- Tests: 18+ files

### Key Search Terms to Replace:
1. `Jarga.Pages` → `Jarga.Documents`
2. `Jarga.Pages.Page` → `Jarga.Documents.Document`
3. `Jarga.Pages.PageComponent` → `Jarga.Documents.DocumentComponent`
4. `Pages.` (context calls) → `Documents.`
5. `get_page_` → `get_document_`
6. `list_pages_` → `list_documents_`
7. `create_page` → `create_document`
8. `update_page` → `update_document`
9. `delete_page` → `delete_document`
10. `"page:"` (PubSub) → `"document:"`
11. `:page_` (atoms/permissions) → `:document_`
12. `page_id` → `document_id` (columns)
13. `/pages/` → `/documents/` (routes)
14. `PageTitleInput` → `DocumentTitleInput`
15. `PageSaveDebouncer` → `DocumentSaveDebouncer`

---

## Notes

- The refactoring respects the Boundary library constraints defined in CLAUDE.md
- All TDD tests should be updated alongside code changes
- Remember to update PubSub subscriptions/broadcasts in BOTH publisher and subscriber code
- The MilkdownEditor hook name can stay generic as it's reused for editing different content types
- After renaming, verify all cross-context references (Notes → Documents) are still correct

