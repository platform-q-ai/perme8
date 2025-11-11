# Phase 1: Preparation Summary

## Completion Date
2025-11-11

## Overview
This document summarizes the findings from Phase 1 preparation for the Pages → Documents and Documents → Agents refactoring.

---

## 1. Documents Context Review (Chat/AI)

### Summary
- **Purpose**: Handles AI agent chat conversations
- **Tables**: `chat_sessions`, `chat_messages` (NO RENAME NEEDED)
- **Context Location**: `lib/jarga/documents/`
- **Files to Rename**: ~14 core files + tests
- **Files to Update**: 5 files (imports/aliases)

### Key Files Using Documents Context
1. `lib/jarga_web/live/chat_live/panel.ex` - Main chat interface
2. `lib/jarga_web/live/app_live/pages/show.ex` - In-editor AI queries
3. `lib/jarga_web.ex` - Boundary configuration
4. Test fixtures: `test/support/fixtures/documents_fixtures.ex`

### External Dependencies
- **Config**: `config/config.exs` - `:chat_context` configuration
- **Environment Variables**:
  - `OPENROUTER_API_KEY`
  - `CHAT_MODEL` (default: "google/gemini-2.0-flash-exp:free")
- **LLM Service**: OpenRouter API integration

### No Database Migration Required
The tables `chat_sessions` and `chat_messages` are already well-named and don't need renaming.

---

## 2. Pages Context Review (User Content)

### Summary
- **Purpose**: User-created pages containing components
- **Tables**: `pages`, `page_components` (WILL BE RENAMED)
- **Context Location**: `lib/jarga/pages/`
- **Files to Rename**: ~14 core files + tests
- **Files to Update**: 60+ files

### Key Files Using Pages Context
1. `lib/jarga_web/live/app_live/pages/show.ex` - Main page editor
2. `lib/jarga_web/live/app_live/projects/show.ex` - Project pages list
3. `lib/jarga_web/live/app_live/workspaces/show.ex` - Workspace pages list
4. `lib/jarga_web/live/page_save_debouncer.ex` - Auto-save functionality
5. `lib/jarga_web/router.ex` - Route definition

### Database Tables to Rename
- `pages` → `documents`
- `page_components` → `document_components`

### Foreign Key References
Tables with `page_id` foreign keys:
1. `page_components.page_id` → Will become `document_components.document_id`
2. `sheet_rows.page_id` → Will become `sheet_rows.document_id`

### PubSub Topics
- `"page:#{page_id}"` → `"document:#{document_id}"`
- Events:
  - `page_visibility_changed` → `document_visibility_changed`
  - `page_pinned_changed` → `document_pinned_changed`
  - `page_title_changed` → `document_title_changed`

### Routes
- `/workspaces/:workspace_slug/pages/:page_slug` → `/workspaces/:workspace_slug/documents/:document_slug`

### JavaScript Files
- `assets/js/page_hooks.js` → `assets/js/editor/document_hooks.js`
- Hooks: `PageTitleInput`, `MilkdownEditor`

### Indexes to Rename
- `pages_pkey` → `documents_pkey`
- `pages_workspace_id_slug_index` → `documents_workspace_id_slug_index`
- `page_components_pkey` → `document_components_pkey`
- Various other page_components indexes

---

## 3. Cross-Context Dependencies

### Notes Context References Pages
Files in `lib/jarga/notes/` that reference Pages:
- May import `Jarga.Pages.PageComponent`
- Need to update to `Jarga.Documents.DocumentComponent`

### Pages Context References Documents (Chat)
The page editor (`pages/show.ex`) uses Documents context for AI queries:
- `Documents.ai_query/2`
- `Documents.cancel_ai_query/2`

---

## 4. Test Coverage Analysis

### Documents (Chat) Tests
- **Unit Tests**: 9 files
- **Integration Tests**: 4 files
- **Fixtures**: 1 file
- **Total**: 14 test files

### Pages Tests
- **Unit Tests**: 11 files
- **LiveView Tests**: 7 files
- **Fixtures**: 1 file
- **Total**: 19 test files

### Test Coverage Status
- All contexts have good test coverage
- Tests currently passing
- Will need updates after renames

---

## 5. External Dependencies & Configuration

### Config Files
- `config/config.exs` - Chat context configuration
- `config/runtime.exs` - OpenRouter API configuration
- No hardcoded "pages" or "documents" terminology in config

### Environment Variables
- `OPENROUTER_API_KEY` - LLM API key
- `CHAT_MODEL` - LLM model selection
- No page-specific environment variables

### Third-Party Integrations
- **OpenRouter API** - Used by Documents/Agents context
- **Yjs** - Real-time collaboration (Notes context)
- No external services directly reference "pages"

---

## 6. Migration Order Recommendation

Based on analysis, the safest order is:

### Step 1: Rename Documents → Agents (No DB migration)
- Rename Elixir context and modules
- Update imports and aliases
- Run tests
- **Risk**: Low (code-only change)

### Step 2: Rename Pages → Documents (Requires DB migration)
- Create and run database migration
- Rename Elixir context and modules
- Update imports and aliases
- Update routes
- Run tests
- **Risk**: Medium (database changes)

### Step 3: Frontend Refactoring
- Reorganize JavaScript files
- Update terminology (AI → Agent)
- **Risk**: Low (incremental changes)

---

## 7. Potential Issues Identified

### Database Migration Challenges
1. **Foreign key constraints** - Need to update `sheet_rows.page_id`
2. **Index renames** - Multiple indexes reference "page"
3. **Unique constraints** - `pages_workspace_id_slug_index`

### PubSub Topic Changes
- Current clients may be subscribed to old topics
- Need to ensure no messages are lost during transition
- Consider supporting both old and new topics temporarily

### Route Changes
- Bookmarked URLs will break
- May need redirects: `/pages/` → `/documents/`
- Consider adding temporary redirect middleware

### Search Risks
- "page" is a common English word
- Care needed with find/replace operations
- May appear in comments, documentation, test descriptions

---

## 8. Rollback Strategy

### If Issues Arise

**Documents → Agents Rollback:**
- Git revert commit
- No database rollback needed
- **Difficulty**: Easy

**Pages → Documents Rollback:**
- Git revert code changes
- Run migration rollback: `mix ecto.rollback`
- Verify data integrity
- **Difficulty**: Medium

---

## 9. Phase 1 Completion Checklist

- [x] Review all Documents (chat) context usage
- [x] Review all Pages context usage
- [x] Identify all database tables and foreign keys
- [x] Document external dependencies
- [x] Identify PubSub topics and events
- [x] Review test coverage
- [x] Create comprehensive file lists
- [x] Document rollback procedures
- [x] Recommend migration order

---

## 10. Next Steps (Phase 2)

### Ready to Proceed With:
1. Create database migration for pages → documents
2. Test migration on development database
3. Verify all foreign keys updated correctly
4. Run all tests
5. Commit migration

### Files Created During Phase 1:
- `PAGES_USAGE_REPORT.md` - Detailed Pages context reference
- `PAGES_REFACTOR_CHECKLIST.md` - Actionable checklist
- `PHASE1_PREPARATION_SUMMARY.md` (this file)

---

## Conclusion

Phase 1 preparation is complete. All context usage has been mapped, external dependencies documented, and migration risks identified. The codebase is ready for Phase 2 database migration.

**Estimated Time for Phase 2**: 2-3 hours
**Risk Level**: Medium (database changes involved)
**Recommended**: Test on development database first
