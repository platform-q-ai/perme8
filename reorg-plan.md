# Reorganization Plan: Pages → Documents, Documents → Agents

## Overview
Transform the codebase from the current structure to a more intuitive naming system:
- **Documents** (chat) → **Agents** (AI conversation functionality)
- **Pages** → **Documents** (user-created content)

---

## Current Structure (Actual)

### Elixir Contexts

**1. Jarga.Documents** (Chat/AI Conversations)
- **Purpose**: Handle AI agent chat conversations
- **Tables**: `chat_sessions`, `chat_messages`
- **Schemas**: `ChatSession`, `ChatMessage`
- **Location**: `lib/jarga/documents/`
- **Use Cases**: `ai_query.ex`, `create_session.ex`, `list_sessions.ex`, `save_message.ex`, etc.

**2. Jarga.Pages** (User Content)
- **Purpose**: User-created pages that contain components
- **Tables**: `pages`, `page_components`
- **Schemas**: `Page`, `PageComponent`
- **Location**: `lib/jarga/pages/`
- **Use Cases**: `create_page.ex`, etc.
- **Components**: Pages contain notes, task_lists, sheets (polymorphic)

**3. Jarga.Notes** (Embedded Components)
- **Purpose**: Yjs-based collaborative editor components embedded in pages
- **Tables**: `notes`
- **Schemas**: `Note`
- **Location**: `lib/jarga/notes/`
- **Stays unchanged** (notes remain as embedded components)

### LiveView Structure

- `lib/jarga_web/live/app_live/pages/show.ex` - Page viewing/editing
- `lib/jarga_web/live/chat_live/panel.ex` - Chat panel with AI
- `lib/jarga_web/live/page_save_debouncer.ex` - Page auto-save

### Routes

```elixir
live "/workspaces/:workspace_slug/pages/:page_slug", AppLive.Pages.Show, :show
```

---

## Target Structure

### Elixir Contexts

**1. Jarga.Agents** (formerly Documents)
- **Purpose**: Handle AI agent chat conversations
- **Tables**: `chat_sessions`, `chat_messages` (unchanged)
- **Schemas**: `ChatSession`, `ChatMessage` (unchanged)
- **Location**: `lib/jarga/agents/`
- **LiveView**: `lib/jarga_web/live/chat_live/` (stays as-is, or could rename to agent_live)

**2. Jarga.Documents** (formerly Pages)
- **Purpose**: User-created documents that contain components
- **Tables**: `documents`, `document_components` (renamed from pages, page_components)
- **Schemas**: `Document`, `DocumentComponent`
- **Location**: `lib/jarga/documents/`
- **LiveView**: `lib/jarga_web/live/app_live/documents/`

**3. Jarga.Notes** (unchanged)
- Embedded components stay the same

### Routes

```elixir
live "/workspaces/:workspace_slug/documents/:document_slug", AppLive.Documents.Show, :show
```

---

## 1. JavaScript Folder Reorganization

### Current Structure (Flat)
```
assets/js/
├── app.js
├── hooks.js
├── page_hooks.js                # Main editor hook
├── collaboration.js
├── ai-mention-plugin.js         # Mention plugin for @ai
├── ai-integration.js            # AI integration
├── ai-response-node.js          # AI response node
├── awareness-plugin.js
├── cursor-decorations.js
├── user-colors.js
├── chat_hooks.js
├── flash_hooks.js
├── collab_editor_observer.js
└── [9 test files]
```

### Proposed Structure (Contextual)
```
assets/js/
├── app.js
├── hooks.js
│
├── editor/                       # Editor-related code
│   ├── document_hooks.js         # Renamed from page_hooks.js
│   ├── collab_editor_observer.js
│   └── nodes/                    # Custom ProseMirror/Milkdown nodes
│       └── agent-response-node.js  # Renamed from ai-response-node.js
│
├── collaboration/                # Real-time collaboration
│   ├── collaboration.js
│   ├── awareness-plugin.js
│   ├── cursor-decorations.js
│   └── user-colors.js
│
├── mentions/                     # Mention system (agents & users)
│   ├── mention-plugin.js         # Renamed from ai-mention-plugin.js
│   └── mention-utils.js          # Extracted duplicate functions
│
├── agents/                       # Agent integration
│   └── agent-integration.js      # Renamed from ai-integration.js
│
├── chat/                         # Chat panel
│   └── chat_hooks.js
│
├── ui/                           # UI utilities
│   └── flash_hooks.js
│
└── __tests__/                    # All test files
    ├── editor/
    ├── collaboration/
    ├── mentions/
    ├── agents/
    └── ...
```

---

## 2. Elixir Backend Changes

### Context Renames

#### A. Documents (Chat) → Agents

**Directory Structure:**
```
lib/jarga/documents/         → lib/jarga/agents/
├── chat_session.ex          → lib/jarga/agents/chat_session.ex (or conversation.ex)
├── chat_message.ex          → lib/jarga/agents/chat_message.ex (or message.ex)
├── queries.ex               → lib/jarga/agents/queries.ex
├── use_cases/
│   ├── ai_query.ex          → use_cases/agent_query.ex
│   ├── create_session.ex
│   ├── list_sessions.ex
│   └── ...
└── infrastructure/
    ├── session_repository.ex
    └── services/
        └── llm_client.ex
```

**Module Renames:**
- `Jarga.Documents` → `Jarga.Agents`
- `Jarga.Documents.ChatSession` → `Jarga.Agents.ChatSession` (or `Conversation`)
- `Jarga.Documents.ChatMessage` → `Jarga.Agents.ChatMessage` (or `Message`)
- Use case modules under `Jarga.Agents.UseCases`

**Database Tables:**
- `chat_sessions` - **NO CHANGE** (already well-named)
- `chat_messages` - **NO CHANGE** (already well-named)

**Note**: We do NOT need to rename the database tables because "chat_sessions" and "chat_messages" are already appropriate names for agent conversations.

#### B. Pages → Documents

**Directory Structure:**
```
lib/jarga/pages/                      → lib/jarga/documents/
├── page.ex                           → lib/jarga/documents/document.ex
├── page_component.ex                 → lib/jarga/documents/document_component.ex
├── queries.ex                        → lib/jarga/documents/queries.ex
├── domain/
│   └── slug_generator.ex
├── infrastructure/
│   └── authorization_repository.ex
├── services/
│   └── component_loader.ex
└── use_cases/
    └── create_page.ex                → create_document.ex
```

**Module Renames:**
- `Jarga.Pages` → `Jarga.Documents`
- `Jarga.Pages.Page` → `Jarga.Documents.Document`
- `Jarga.Pages.PageComponent` → `Jarga.Documents.DocumentComponent`
- All use cases and services updated accordingly

**Database Tables:**
- `pages` → `documents`
- `page_components` → `document_components`

**Foreign Keys:**
- `page_id` → `document_id` (in `page_components`, `sheet_rows`, etc.)

#### C. LiveView Changes

**Current:**
```
lib/jarga_web/live/
├── app_live/
│   └── pages/
│       └── show.ex              # AppLive.Pages.Show
├── chat_live/
│   ├── panel.ex
│   └── ...
└── page_save_debouncer.ex
```

**Target:**
```
lib/jarga_web/live/
├── app_live/
│   └── documents/               # Renamed from pages/
│       └── show.ex              # AppLive.Documents.Show
├── chat_live/                   # Could rename to agent_live/ (optional)
│   ├── panel.ex
│   └── ...
└── document_save_debouncer.ex   # Renamed from page_save_debouncer.ex
```

---

## 3. Database Migration Strategy

### Key Insight: No Table Renames for Chat

The `chat_sessions` and `chat_messages` tables are **already well-named** and do NOT need to be renamed. We only rename the Elixir context from `Documents` to `Agents`, not the tables.

### Required Migrations

**Migration 1: Rename Pages Tables**

```elixir
defmodule Jarga.Repo.Migrations.RenamePagesToDocuments do
  use Ecto.Migration

  def up do
    # Rename pages table to documents
    rename table(:pages), to: table(:documents)

    # Rename page_components to document_components
    rename table(:page_components), to: table(:document_components)

    # Update foreign key in document_components
    rename table(:document_components), :page_id, to: :document_id

    # Update foreign key in sheet_rows (if it references pages)
    rename table(:sheet_rows), :page_id, to: :document_id

    # Update index names
    execute "ALTER INDEX pages_pkey RENAME TO documents_pkey"
    execute "ALTER INDEX pages_workspace_id_slug_index RENAME TO documents_workspace_id_slug_index"
    execute "ALTER INDEX page_components_pkey RENAME TO document_components_pkey"

    # Note: May need to update other indexes and constraints
  end

  def down do
    # Reverse all changes
    execute "ALTER INDEX documents_pkey RENAME TO pages_pkey"
    execute "ALTER INDEX documents_workspace_id_slug_index RENAME TO pages_workspace_id_slug_index"
    execute "ALTER INDEX document_components_pkey RENAME TO page_components_pkey"

    rename table(:sheet_rows), :document_id, to: :page_id
    rename table(:document_components), :document_id, to: :page_id
    rename table(:document_components), to: table(:page_components)
    rename table(:documents), to: table(:pages)
  end
end
```

**No Migration Needed for Documents → Agents** because the tables remain `chat_sessions` and `chat_messages`.

---

## 4. Terminology Changes: AI → Agents

### File Renames

| Current | New | Location |
|---------|-----|----------|
| `ai-mention-plugin.js` | `mention-plugin.js` | `mentions/` |
| `ai-integration.js` | `agent-integration.js` | `agents/` |
| `ai-response-node.js` | `agent-response-node.js` | `editor/nodes/` |
| `ai-response.css` | `agent-response.css` | `assets/css/` |
| `page_hooks.js` | `document_hooks.js` | `editor/` |
| `page_save_debouncer.ex` | `document_save_debouncer.ex` | `lib/jarga_web/live/` |

### Code Terminology Changes

**Function Names:**
- `handleAIQuery()` → `handleAgentQuery()`
- `createAIMentionPlugin()` → `createMentionPlugin()`
- `updateAIResponseNode()` → `updateAgentResponseNode()`
- `AIAssistantManager` → `AgentManager`
- `ai_response` (node type) → `agent_response`

**Phoenix Events:**
- `ai_chunk` → `agent_chunk`
- `ai_done` → `agent_done`

**CSS Classes:**
- `.ai-response` → `.agent-response`
- `.ai-loading` → `.agent-loading`

**Mention Trigger:**
- `@ai` → `@j` (for Jarga)

---

## 5. Key Refactoring: Extract Duplicate Functions

**Problem:** `updateAgentResponseNode()` and `appendChunkToNode()` exist in both:
- `mention-plugin.js`
- `agent-response-node.js`

**Solution:** Create `mentions/mention-utils.js`

```javascript
// mention-utils.js
export function updateAgentResponseNode(view, nodePos, content) { ... }
export function appendChunkToNode(view, nodePos, chunk) { ... }
export function findAgentResponseNode(doc, agentId) { ... }
```

Import in both files from single source of truth.

---

## 6. Migration Strategy (Phases)

### Phase 1: Prepare & Test (1-2 hours)
1. Review all `Documents` (chat) context usage in codebase
2. Review all `Pages` context usage
3. Create comprehensive test coverage gaps list
4. Document all external dependencies
5. Create feature branch: `language-refactor` (already exists)

### Phase 2: Database Migration - Pages → Documents (2-3 hours)
1. Create migration for pages → documents rename
2. Test migration on development database
3. Verify all foreign keys updated correctly
4. Run all tests
5. Commit migration

### Phase 3: Backend Rename - Pages → Documents (3-4 hours)
1. Rename directory: `lib/jarga/pages/` → `lib/jarga/documents/`
2. Update all Elixir modules: `Jarga.Pages` → `Jarga.Documents`
3. Update schema names: `Page` → `Document`, `PageComponent` → `DocumentComponent`
4. Update all imports and aliases throughout codebase
5. Update LiveView modules: `AppLive.Pages` → `AppLive.Documents`
6. Update router routes: `/pages/` → `/documents/`
7. Run all tests

### Phase 4: Backend Rename - Documents → Agents (3-4 hours)
1. Rename directory: `lib/jarga/documents/` → `lib/jarga/agents/`
2. Update all Elixir modules: `Jarga.Documents` → `Jarga.Agents`
3. Update all imports and aliases throughout codebase
4. Update use case module names (`AIQuery` → `AgentQuery`)
5. Consider renaming `ChatLive` → `AgentLive` (optional)
6. Run all tests

### Phase 5: Frontend Structure Reorganization (2-3 hours)
1. Create new folder structure in `assets/js/`
2. Move files to new locations:
   - `page_hooks.js` → `editor/document_hooks.js`
   - `collab_editor_observer.js` → `editor/`
   - Collaboration files → `collaboration/`
   - Chat files → `chat/`
3. Update import paths in all JavaScript files
4. Update `app.js` imports
5. Run frontend tests

### Phase 6: Frontend Terminology - AI → Agents (3-4 hours)
1. Rename files:
   - `ai-mention-plugin.js` → `mentions/mention-plugin.js`
   - `ai-integration.js` → `agents/agent-integration.js`
   - `ai-response-node.js` → `editor/nodes/agent-response-node.js`
2. Extract duplicate utilities to `mentions/mention-utils.js`
3. Update function names and class names (AI → Agent)
4. Change `@ai` to `@j` mention trigger
5. Update Phoenix channels event names (`ai_chunk` → `agent_chunk`)
6. Update CSS classes and rename `ai-response.css` → `agent-response.css`
7. Run all tests

### Phase 7: Documentation & Cleanup (2-3 hours)
1. Delete old files (if any orphans remain)
2. Update README and documentation
3. Update architecture diagrams
4. Search for remaining references:
   - "pages" (in context of documents)
   - "documents" (in context of agents)
   - "ai" (in context of agents)
5. Final comprehensive test run
6. Update deployment scripts if needed

---

## 7. Testing Checklist

After each phase, verify:

- [ ] All Elixir tests pass (`mix test`)
- [ ] All JavaScript tests pass (`npm test`)
- [ ] No compilation errors (`mix compile`)
- [ ] Editor loads correctly
- [ ] Can create new documents (formerly pages)
- [ ] Can view/edit existing documents
- [ ] Document slugs work correctly in URLs
- [ ] `@j` mentions trigger agent responses (formerly `@ai`)
- [ ] Agent chat works correctly (formerly documents context)
- [ ] Agent responses stream correctly
- [ ] Markdown parsing works
- [ ] Collaboration still works
- [ ] Chat panel functional
- [ ] No console errors
- [ ] Build succeeds (`mix assets.deploy`)
- [ ] Database queries work correctly
- [ ] All routes accessible:
  - [ ] `/workspaces/:slug/documents/:slug` route works (formerly `/pages/`)
- [ ] LiveView updates properly
- [ ] Foreign key relationships work (document associations)
- [ ] Boundary checks pass (`mix boundary`)

---

## 8. Risks & Considerations

### Database Migration

**Complexity:**
- Table renames can be tricky with foreign keys and indexes
- Need to update ALL foreign key references
- Index names need updating
- Constraint names need updating

**Mitigation:**
- Test migration thoroughly on development
- Backup production database
- Have rollback plan ready
- Consider brief maintenance window

### Context Name Collision

**Issue:** During transition, "Documents" will temporarily exist in both:
1. Old location (`lib/jarga/documents/` for chat)
2. New location (after renaming from `pages`)

**Solution:** Rename in clear sequence:
1. First commit: Rename Pages → Documents (new)
2. Must happen AFTER: Rename old Documents → Agents
3. Or do in reverse: Documents → Agents first, then Pages → Documents

**Recommended Order:**
1. **First**: Rename `Documents` (chat) → `Agents`
2. **Then**: Rename `Pages` → `Documents`

This avoids any conflict.

### Phoenix Channels

- Event name changes (`ai_chunk` → `agent_chunk`) must be coordinated
- Backend and frontend must be deployed simultaneously
- No graceful degradation during mismatched events

### Route Changes

**Old:** `/workspaces/:workspace_slug/pages/:page_slug`
**New:** `/workspaces/:workspace_slug/documents/:document_slug`

**Impacts:**
- Bookmarked URLs will break
- Need redirects or update bookmarks
- External links need updating
- May confuse users

**Consider:** Add redirect in router temporarily

### User Experience

- Changing `@ai` to `@j` changes user behavior
- Consider in-app announcement or tooltip
- Update any user documentation

### Search & Replace Dangers

- "page" and "document" are common English words
- Appears in comments, documentation, variable names
- Must review each change carefully
- Use case-sensitive find/replace
- Grep for exact pattern matches

---

## 9. Files Requiring Updates

### Elixir Files (Backend)

**Documents → Agents:**
- `lib/jarga/documents/` → `lib/jarga/agents/` (entire directory)
- All files with `alias Jarga.Documents` → `alias Jarga.Agents`
- All use case tests in `test/jarga/documents/` → `test/jarga/agents/`
- Any tests referencing Documents context

**Pages → Documents:**
- `lib/jarga/pages/` → `lib/jarga/documents/` (entire directory)
- All files with `alias Jarga.Pages` → `alias Jarga.Documents`
- Router: `lib/jarga_web/router.ex`
- LiveView: `lib/jarga_web/live/app_live/pages/` → `lib/jarga_web/live/app_live/documents/`
- `lib/jarga_web/live/page_save_debouncer.ex` → `document_save_debouncer.ex`
- All tests in `test/jarga/pages/` → `test/jarga/documents/`
- All LiveView tests

**Cross-references to update:**
- Any context that references Pages (check Notes, Projects, Workspaces)
- Any context that references Documents/chat (check Chat LiveView)

### JavaScript Files (Frontend)

**Renames:**
- `assets/js/ai-mention-plugin.js` → `assets/js/mentions/mention-plugin.js`
- `assets/js/ai-integration.js` → `assets/js/agents/agent-integration.js`
- `assets/js/ai-response-node.js` → `assets/js/editor/nodes/agent-response-node.js`
- `assets/js/page_hooks.js` → `assets/js/editor/document_hooks.js`

**Terminology updates:**
- `assets/js/chat_hooks.js` (if using mentions or AI references)
- `assets/js/app.js` (import paths)
- Any test files

### CSS Files

- `assets/css/ai-response.css` → `assets/css/agent-response.css`
- Any other CSS files with `.ai-` classes

### Test Files

- All test files in corresponding directories
- Update test descriptions and assertions
- Update factory/fixture references (if any)

### Configuration

- Check `config/` files for any hardcoded references
- Check environment variable names
- Check application configuration

---

## 10. Estimated Effort

- **Phase 1 (Prepare):** 1-2 hours
- **Phase 2 (Database Migration):** 2-3 hours (includes testing)
- **Phase 3 (Backend - Pages → Documents):** 3-4 hours
- **Phase 4 (Backend - Documents → Agents):** 3-4 hours
- **Phase 5 (Frontend Structure):** 2-3 hours
- **Phase 6 (Frontend Terminology):** 3-4 hours
- **Phase 7 (Docs/Cleanup):** 2-3 hours

**Total:** ~16-23 hours

---

## 11. Rollback Plan

If issues arise during migration:

### Database Rollback

1. **Preferred**: Run down migration
   ```bash
   mix ecto.rollback --step=1
   ```

2. **Emergency**: Restore from backup
   - Stop application
   - Restore database backup
   - Verify data integrity

### Code Rollback

1. **Git revert**: Revert commit(s)
   ```bash
   git revert <commit-hash>
   git push
   ```

2. **Branch rollback**: Switch back to main/previous branch
   ```bash
   git checkout main
   ```

### Partial Rollback

If you need to keep code but rollback database:
- Restore database backup
- Code still references old schema - won't work
- Must revert code too

**Recommendation:** Test entire migration on staging environment first.

---

## 12. Success Criteria

Migration is successful when:

1. ✅ All tests pass (Elixir and JavaScript)
2. ✅ No compilation errors or warnings (except boundary if needed)
3. ✅ No console errors in browser
4. ✅ Users can create and edit documents (formerly pages)
5. ✅ Agent chat system works correctly (formerly documents)
6. ✅ `@j` mentions work correctly (formerly `@ai`)
7. ✅ Agent responses stream and parse properly
8. ✅ Collaboration features work
9. ✅ Chat panel functions correctly
10. ✅ Database queries perform as expected
11. ✅ All routes work correctly
12. ✅ No broken links or 404 errors
13. ✅ Foreign key relationships intact
14. ✅ Code organization is logical and documented
15. ✅ No naming conflicts or ambiguous terminology

---

## 13. Post-Migration Tasks

- [ ] Monitor error logs for 24-48 hours
- [ ] Gather user feedback on `@j` mention trigger
- [ ] Verify all routes working correctly
- [ ] Check for any remaining references to old terminology
- [ ] Update any external documentation or integrations
- [ ] Consider adding user mention support (`@username`)
- [ ] Review and optimize new folder structure
- [ ] Create ADR (Architecture Decision Record) documenting changes
- [ ] Update onboarding documentation if applicable
- [ ] Consider adding redirects for old URLs

---

## 14. Questions Before Starting

1. **Timing:** When is the best time to perform this migration (low traffic period)?

2. **User Communication:** Should users be notified about the terminology changes?
   - `@ai` → `@j`
   - "Pages" → "Documents"

3. **Backwards Compatibility:** Do we need to support both `@ai` and `@j` temporarily?

4. **Migration Order:** Should we do Documents→Agents first, or Pages→Documents first?
   - **Recommendation:** Documents → Agents FIRST to free up the name

5. **Feature Branch:** Continue on `language-refactor` branch or new branch?

6. **Deployment:** Can backend and frontend be deployed simultaneously?

7. **Redirects:** Should we add URL redirects for `/pages/` → `/documents/`?

---

## 15. Additional Notes

### Architecture Benefits

- **Clearer domain separation:**
  - **Documents** = User-created content (what users write/edit)
  - **Agents** = AI assistants that respond to queries
  - **Notes** = Embedded editor components within documents
- Clearer separation of concerns
- Easier to locate and modify specific features
- Better aligns with planned agent system
- More intuitive for new developers

### Terminology Consistency

- "Agent" better represents AI assistants than "AI" or "Documents"
- "Document" better represents user content than "Page"
- "Mentions" is neutral and extensible (can add `@username` later)
- Matches industry standards (Slack, Discord, Notion, etc.)

### Future Extensibility

- The `mentions/` folder is positioned to handle both agent (`@j`) and user (`@username`) mentions
- Consider adding a mention type discriminator in the plugin
- Plan for mention autocomplete UI in future iterations
- Agent system can be extended with different agent types

### Migration Complexity Notes

- **Simpler than originally thought**: Chat tables don't need renaming
- Only Pages → Documents requires database migration
- Documents → Agents is purely code rename
- Clear rollback points with sequential commits

---

## 16. Recommended Migration Order

Based on analysis, here's the safest order:

### Step 1: Rename Documents (Chat) → Agents
- **Why first?** Frees up the "Documents" name
- No database migration needed
- Lower risk
- Clear rollback point

### Step 2: Rename Pages → Documents
- **Why second?** Now "Documents" name is available
- Requires database migration
- Higher risk but isolated
- Clear rollback point

### Step 3: Frontend Refactoring
- File reorganization
- Terminology updates
- Can be done incrementally

This sequential approach provides:
- Clear rollback points between each step
- Easier debugging
- Lower risk of conflicts
- Ability to pause between phases
