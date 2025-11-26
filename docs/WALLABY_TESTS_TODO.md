# Wallaby Tests Implementation TODO

**Created:** 2025-11-27  
**Purpose:** Get all `@javascript` feature tests passing with Wallaby browser testing  
**Status:** 🔴 In Progress

---

## Overview

Currently 13 tests are failing because they require real browser interaction via Wallaby. This document tracks the work needed to get all Wallaby tests passing.

**Test Results:**
- Total: 265 tests
- Passing (LiveViewTest): 252 (95.1%)
- Failing (Need Wallaby): 13 (4.9%)

---

## Phase 1: Setup & Investigation (Understand Current State)

### Task 1.1: Verify Wallaby Configuration
- [ ] Check `config/test.exs` for Wallaby configuration
- [ ] Verify ChromeDriver is installed and accessible
- [ ] Check test helper for Wallaby setup
- [ ] Verify FeatureCase has Wallaby support module

### Task 1.2: Run Wallaby Tests to See Current State
- [ ] Run: `mix test --include wallaby test/support/feature_case.ex`
- [ ] Document actual error messages for each failing test
- [ ] Identify common patterns in failures

---

## Phase 2: Fix Missing Step Definitions

### Task 2.1: Viewport & Browser Setup Steps
**Status:** ⏸️ Not Started  
**Tests Affected:** 5 (desktop/mobile viewport tests)

Missing steps that need implementation:
- [ ] **"I am on any page with the admin layout for browser tests"** (line 38 in browser_steps)
  - Currently references undefined helper `create_browser_session`
  - Need to implement Wallaby session creation with Ecto Sandbox
  - Need to implement `login_user_via_real_login` helper

- [ ] **"the page loads for browser tests"** 
  - Get page HTML from Wallaby session
  - Store in context for assertions

- [ ] **"I have not previously interacted with the chat panel for browser tests"**
  - Already defined but may need refinement

**Files to modify:**
- `test/features/step_definitions/chat_panel_browser_steps.exs`

### Task 2.2: Resize Functionality Steps  
**Status:** ⏸️ Not Started  
**Tests Affected:** 4 (resize scenarios)

Steps already defined but may need fixes:
- [x] "I drag the resize handle to the left" - Already defined
- [x] "I drag the resize handle to the right" - Already defined
- [x] "the panel width should increase" - Already defined
- [x] "the panel width should decrease" - Already defined
- [x] "I resize the panel to {int} px width" - Already defined
- [ ] Verify these work with actual Wallaby session

**Potential Issues:**
- DOM selector `#global-chat-panel` may not exist or be incorrect
- Need to verify panel structure in actual rendered HTML
- May need different approach than `execute_script` for resize

**Files to check:**
- `test/features/step_definitions/chat_panel_browser_steps.exs` (lines 86-232)

### Task 2.3: Streaming Steps
**Status:** ⏸️ Not Started  
**Tests Affected:** 1 (streaming chunks test)

Currently streaming steps are in `chat_panel_response_steps.exs` and check for `context[:session]` to skip for Wallaby. Need to verify:
- [ ] Streaming steps work with Wallaby session
- [ ] MockLlmClient integration works in browser tests
- [ ] Chunks appear in actual rendered HTML

**Files to check:**
- `test/features/step_definitions/chat_panel_response_steps.exs`

### Task 2.4: Agent Update & PubSub Steps
**Status:** ⏸️ Not Started  
**Tests Affected:** 2 (agent updates)

Steps that need fixes:
- [ ] **"the chat panel in both workspaces should reflect the changes"**
  - Currently expects PubSub broadcast that may not occur
  - Need to verify agent update triggers workspace sync

- [ ] **"the new agent should appear in the selector"**
  - Need to verify agent selector HTML
  - May need to wait for LiveView update

**Files to check:**
- `test/features/step_definitions/chat_panel_agent_steps.exs`

### Task 2.5: Focus & Keyboard Navigation
**Status:** ⏸️ Not Started  
**Tests Affected:** 1 (focus on initial load)

Steps that may need Wallaby implementation:
- [ ] **"the message input should receive focus"**
  - Verify focus via Wallaby's `assert_has(css("...:focus"))`
  - Check if focus-editor event fires correctly

**Files to check:**
- `test/features/step_definitions/chat_panel_ui_steps.exs`

### Task 2.6: Empty Chat State
**Status:** ⏸️ Not Started  
**Tests Affected:** 1 (empty chat welcome)

Steps to verify:
- [ ] **"I should see the welcome icon (chat bubble)"**
  - Verify icon appears in Wallaby-rendered HTML
  - May need different selector

**Files to check:**
- `test/features/step_definitions/chat_panel_common_steps.exs`

---

## Phase 3: Implement Wallaby Browser Session Helpers

### Task 3.1: Create Browser Session with Sandbox
**Status:** ⏸️ Not Started

Implement helper function in `chat_panel_browser_steps.exs`:
```elixir
defp create_browser_session do
  # Set up Ecto Sandbox
  case Ecto.Adapters.SQL.Sandbox.checkout(Jarga.Repo) do
    :ok -> :ok
    {:already, :owner} -> :ok
  end

  Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, {:shared, self()})

  # Get sandbox metadata for Wallaby session
  metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Jarga.Repo, self())

  # Start a Wallaby session with sandbox metadata
  {:ok, session} = Wallaby.start_session(metadata: metadata)
  session
end
```

**Verify:**
- [ ] Session starts successfully
- [ ] Sandbox metadata is passed correctly
- [ ] Database transactions work in browser tests

### Task 3.2: Implement Real Login Flow
**Status:** ⏸️ Not Started

Implement login helper:
```elixir
defp login_user_via_real_login(session, user, password \\ "hello world!") do
  session
  |> Wallaby.Browser.visit("/users/log-in")
  |> Wallaby.Browser.fill_in(css("#login_form_password_email"), with: user.email)
  |> Wallaby.Browser.fill_in(css("#login_form_password_password"), with: password)
  |> Wallaby.Browser.click(button("Log in and stay logged in"))
  |> then(fn session ->
    Process.sleep(1000)  # Wait for redirect
    session
  end)
end
```

**Verify:**
- [ ] Login form selectors are correct
- [ ] Login completes successfully
- [ ] Session is authenticated for subsequent requests

---

## Phase 4: Fix Specific Test Failures

### Test 1: "Update agent and notify affected workspaces"
**Feature:** `test/features/agents.feature:93`  
**Status:** ⏸️ Not Started

**Issue:** Step "the chat panel in both workspaces should reflect the changes" fails
- PubSub broadcast not received or agent update doesn't trigger sync

**Actions:**
- [ ] Check if agent update actually triggers `sync_agent_workspaces`
- [ ] Verify PubSub subscription is active before update
- [ ] May need to make assertion more lenient (check database instead of PubSub)

### Test 2-4: Resize Tests (3 tests)
**Features:** 
- `test/features/chat_panel.feature:56` - "Chat panel is resizable"
- `test/features/chat_panel.feature:66` - "Resized chat panel persists across page navigation"
- `test/features/chat_panel.feature:74` - "Resized chat panel maintains width during agent response"

**Status:** ⏸️ Not Started

**Issue:** Step "I resize the panel to {int} px width" not found or fails

**Actions:**
- [ ] Verify `#global-chat-panel` selector exists in actual HTML
- [ ] Check if panel has inline width style or uses CSS classes
- [ ] May need to trigger resize via mouse drag simulation instead of `execute_script`
- [ ] Verify localStorage integration works

### Test 5-7: Viewport & State Tests (3 tests)
**Features:**
- `test/features/chat_panel.feature:10` - "Chat panel opens by default on desktop"
- `test/features/chat_panel.feature:21` - "Chat panel closed by default on mobile"  
- `test/features/chat_panel.feature:553` - "Chat panel auto-adjusts on resize without user interaction"

**Status:** ⏸️ Not Started

**Issue:** Missing browser navigation/setup steps

**Actions:**
- [ ] Implement "I am on any page with the admin layout for browser tests"
- [ ] Implement viewport resize steps
- [ ] Verify drawer state (checked/unchecked) in HTML
- [ ] Check DaisyUI drawer structure

### Test 8: "Receive streaming chunks via Phoenix LiveView"
**Feature:** `test/features/chat_panel.feature:466`  
**Status:** ⏸️ Not Started

**Issue:** Step "the chunk should be appended to the stream buffer" fails

**Actions:**
- [ ] Verify MockLlmClient works in Wallaby tests
- [ ] Check if streaming chunks actually appear in browser
- [ ] May need to wait longer for chunks to arrive
- [ ] Verify WebSocket connection is established

### Test 9: "Chat panel updates when agents change"
**Feature:** `test/features/chat_panel.feature:492`  
**Status:** ⏸️ Not Started

**Issue:** Step "the new agent should appear in the selector" fails

**Actions:**
- [ ] Verify agent creation triggers LiveView update
- [ ] Check agent selector HTML structure
- [ ] May need to wait for PubSub broadcast and LiveView re-render
- [ ] Use Wallaby's `assert_has` with retry logic

### Test 10: "Empty chat shows welcome message"
**Feature:** `test/features/chat_panel.feature:84`  
**Status:** ⏸️ Not Started

**Issue:** Welcome message or icon not found

**Actions:**
- [ ] Verify empty chat state HTML structure
- [ ] Check for correct icon class or SVG
- [ ] Verify "Ask me anything" text appears

### Test 11-12: User Preference Tests (2 tests)
**Features:**
- `test/features/chat_panel.feature:40` - "Chat panel restores user preference across page loads"
- `test/features/chat_panel.feature:562` - "Chat panel preserves user preference during resize"

**Status:** ⏸️ Not Started

**Issue:** localStorage not being set or read correctly

**Actions:**
- [ ] Verify localStorage operations via Wallaby
- [ ] Check localStorage keys used (chatPanelOpen, chatPanelWidth)
- [ ] Test navigation preserves state
- [ ] Verify LiveView mount reads localStorage

### Test 13: "Message input receives focus on desktop initial load"
**Feature:** Line unknown  
**Status:** ⏸️ Not Started

**Issue:** Focus not detected or hook not firing

**Actions:**
- [ ] Verify focus-editor hook is registered
- [ ] Check if input actually receives focus
- [ ] Use Wallaby to check `:focus` pseudo-selector
- [ ] May need to wait for animation to complete

---

## Phase 5: Integration & Verification

### Task 5.1: Run All Wallaby Tests
- [ ] Run: `mix test --include wallaby test/support/feature_case.ex`
- [ ] Verify all 13 tests now pass
- [ ] Check for any new failures

### Task 5.2: Run Full Test Suite
- [ ] Run: `mix test`
- [ ] Verify no regressions in LiveViewTest scenarios
- [ ] Check total pass rate (should be 100%)

### Task 5.3: CI Integration
- [ ] Verify Wallaby tests work in CI environment
- [ ] Check ChromeDriver installation in CI
- [ ] May need to configure headless mode

---

## Phase 6: Documentation & Cleanup

### Task 6.1: Update Test Documentation
- [ ] Document Wallaby test patterns in `docs/prompts/architect/FEATURE_TESTING_GUIDE.md`
- [ ] Add examples of browser-specific steps
- [ ] Document when to use `@javascript` tag

### Task 6.2: Code Cleanup
- [ ] Remove any commented-out code from browser_steps.exs
- [ ] Ensure all helpers are documented
- [ ] Verify imports are minimal and necessary

### Task 6.3: Create Summary Report
- [ ] Update BDD_STEP_IMPLEMENTATION_TODO.md with completion status
- [ ] Document final test results
- [ ] List any known limitations or browser-specific quirks

---

## Common Issues & Solutions

### Issue: "ChromeDriver not found"
**Solution:** Install ChromeDriver
```bash
# macOS
brew install --cask chromedriver

# Ubuntu/Debian
sudo apt-get install chromium-chromedriver

# Or use webdrivers package to auto-manage
```

### Issue: "Session not found" or "Stale element reference"
**Solution:** Add waits and retry logic
```elixir
# Wait for element
Wallaby.Browser.assert_has(session, css(".chat-panel"), count: 1)

# Retry on stale element
retry(fn ->
  session
  |> find(css(".message"))
  |> click()
end)
```

### Issue: "Database locked" or "Sandbox errors"
**Solution:** Ensure proper sandbox setup
```elixir
# In test helper or feature case
Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, {:shared, self()})
```

### Issue: "Element not visible" or "Element not interactable"
**Solution:** Scroll or wait for animations
```elixir
# Scroll into view
Wallaby.Browser.execute_script(
  session,
  "arguments[0].scrollIntoView()", 
  [element]
)

# Wait for animation
Process.sleep(500)
```

---

## Progress Tracking

**Phase 1:** ⏸️ Not Started  
**Phase 2:** ⏸️ Not Started  
**Phase 3:** ⏸️ Not Started  
**Phase 4:** ⏸️ Not Started  
**Phase 5:** ⏸️ Not Started  
**Phase 6:** ⏸️ Not Started

**Overall Progress:** 0% (0/13 tests passing)

---

## Next Steps

1. ✅ Create this TODO document
2. ⏸️ Start with Phase 1: Verify Wallaby configuration
3. ⏸️ Implement browser session helpers (Phase 3)
4. ⏸️ Fix one test at a time (Phase 4)
5. ⏸️ Run full suite and verify (Phase 5)

**Estimated Time:** 4-6 hours

**Priority Order:**
1. Phase 1 & 3 (Setup & Helpers) - Required foundation
2. Tests 2-4 (Resize) - Core functionality, well-defined
3. Tests 5-7 (Viewport) - Uses same helpers as above
4. Test 10 (Empty chat) - Simple verification
5. Tests 11-12 (localStorage) - Builds on resize work
6. Test 8 (Streaming) - More complex, may need LLM mock fixes
7. Tests 1, 9, 13 (PubSub/Focus) - Most complex, may have architecture issues

---

## Notes

- All resize and viewport steps are now in `chat_panel_browser_steps.exs` (no duplicates)
- Streaming steps check for `context[:session]` and skip Wallaby-specific logic
- Most failures are due to missing browser session setup, not step logic
- MockLlmClient should work but may need verification in browser context
- Focus and PubSub tests may reveal architectural issues worth documenting

