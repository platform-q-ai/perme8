# PubSub Testing Guide for Cucumber BDD Tests

## Overview

This guide covers best practices for testing Phoenix PubSub broadcasts in Cucumber/BDD feature tests. PubSub testing ensures that real-time notifications work correctly across the application.

## Testing Approaches

### 1. **PubSub Broadcast Verification** (Verify Message Sent)

Test that the broadcast is sent with the correct message structure.

**Pattern:**
```elixir
step "user {string} is viewing workspace {string}",
     %{args: [_user_email, _workspace_slug]} = context do
  workspace = context[:workspace]
  
  # Subscribe to PubSub to simulate another user watching the workspace
  Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
  
  {:ok, context |> Map.put(:pubsub_subscribed, true)}
end

step "user {string} should receive a project created notification",
     %{args: [_user_email]} = context do
  project = context[:project]
  
  # Verify we received the project created broadcast
  assert_receive {:project_added, project_id}, 1000
  assert project_id == project.id
  
  {:ok, context}
end
```

**Pros:**
- ✅ Fast execution
- ✅ No need for multiple browser sessions
- ✅ Tests the broadcast mechanism directly
- ✅ Works in ConnCase (no Wallaby needed)

**Cons:**
- ⚠️ Doesn't test the LiveView handle_info/2 callback
- ⚠️ Doesn't verify UI updates

### 2. **LiveView Real-Time Update Testing** (Recommended for UI Updates)

Test that LiveView processes PubSub messages and updates the UI correctly using the same LiveView connection.

**Pattern:**
```elixir
step "user {string} is viewing workspace {string}",
     %{args: [_user_email, _workspace_slug]} = context do
  import Phoenix.LiveViewTest
  
  workspace = context[:workspace]
  conn = context[:conn]
  
  # Subscribe to PubSub to receive real-time notifications
  Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
  
  # Mount and keep the LiveView connection alive for real-time testing
  {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
  
  {:ok,
   context
   |> Map.put(:pubsub_subscribed, true)
   |> Map.put(:workspace_view, view)
   |> Map.put(:last_html, html)}
end

step "the new project should appear in their workspace view", context do
  import Phoenix.LiveViewTest
  
  project = context[:project]
  view = context[:workspace_view]
  
  # Simulate the PubSub message that the LiveView would receive
  # This tests the handle_info/2 callback directly
  send(view.pid, {:project_added, project.id})
  
  # Render the view to see the effects of the PubSub message
  html = render(view)
  
  # Verify the new project appears in the workspace view
  name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
  assert html =~ name_escaped
  
  {:ok, context |> Map.put(:last_html, html)}
end
```

**Pros:**
- ✅ Tests the actual handle_info/2 callback
- ✅ Verifies that LiveView assigns change in response to messages
- ✅ Tests the real-time update mechanism directly
- ✅ Still maintains full-stack testing (HTTP → HTML)
- ✅ Faster than mounting new connections
- ✅ No Wallaby needed

**Cons:**
- ⚠️ Requires storing LiveView connection in context

### 3. **Full Integration with Wallaby** (For @javascript scenarios)

Test the complete real-time update flow with actual browser sessions, including JavaScript handling.

**Pattern:**
```elixir
@tag :wallaby
test "real-time title update", %{session: session} do
  # Session 1: Alice's browser
  alice_session = session
    |> visit("/document/123")
  
  # Session 2: Charlie's browser  
  charlie_session = Wallaby.start_session()
    |> visit("/document/123")
  
  # Alice updates title
  alice_session
    |> fill_in(Query.css("#document-title"), with: "New Title")
    |> blur(Query.css("#document-title"))
  
  # Charlie sees the update in real-time
  assert charlie_session
    |> has?(Query.css("#document-title", text: "New Title"))
end
```

**Pros:**
- ✅ Tests complete end-to-end flow
- ✅ Tests LiveView push and JavaScript handling
- ✅ Tests actual UI updates in real browsers

**Cons:**
- ⚠️ Slow (requires browser automation)
- ⚠️ Complex setup with multiple sessions
- ⚠️ Only works with `@javascript` tag

## Recommended Approach

Use a **three-tier testing strategy**:

### Tier 1: PubSub Broadcast Verification (Always Required)

Verify that the PubSub message is broadcast with correct data:

```elixir
step "user {string} should receive a project created notification",
     %{args: [_user_email]} = context do
  project = context[:project]
  
  # Verify the PubSub broadcast was received
  assert_receive {:project_added, project_id}, 1000
  assert project_id == project.id
  
  {:ok, context}
end
```

### Tier 2: LiveView Real-Time Update Testing (Recommended for UI)

Test that LiveView processes the message and updates UI:

```elixir
# Setup: Store LiveView connection
step "user {string} is viewing workspace {string}",
     %{args: [_user_email, _workspace_slug]} = context do
  import Phoenix.LiveViewTest
  
  workspace = context[:workspace]
  conn = context[:conn]
  
  Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
  {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
  
  {:ok,
   context
   |> Map.put(:workspace_view, view)
   |> Map.put(:last_html, html)}
end

# Test: Simulate PubSub message and verify UI update
step "the new project should appear in their workspace view", context do
  import Phoenix.LiveViewTest
  
  project = context[:project]
  view = context[:workspace_view]
  
  # Test handle_info/2 callback
  send(view.pid, {:project_added, project.id})
  html = render(view)
  
  # Verify UI update
  assert html =~ project.name
  
  {:ok, context |> Map.put(:last_html, html)}
end
```

### Tier 3: Wallaby Browser Testing (Optional for Complex JavaScript)

Only use for scenarios that require actual JavaScript interaction:

```elixir
@javascript
Scenario: Multiple users edit document simultaneously
  Given I am logged in as "alice@example.com"
  And a public document exists with title "Collaborative Doc"
  And user "charlie@example.com" is also viewing the document
  When I make changes to the document content
  Then user "charlie@example.com" should see my changes in real-time
```

## Complete Example: Project Real-Time Updates

### Feature File:
```gherkin
Scenario: Project creation notification to workspace members
  Given I am logged in as "alice@example.com"
  And user "charlie@example.com" is viewing workspace "product-team"
  When I create a project with name "New Project" in workspace "product-team"
  Then user "charlie@example.com" should receive a project created notification
  And the new project should appear in their workspace view

Scenario: Project update notification to workspace members
  Given I am logged in as "alice@example.com"
  And a project exists with name "Mobile App" owned by "alice@example.com"
  And user "charlie@example.com" is viewing workspace "product-team"
  When I update the project name to "Mobile Application"
  Then user "charlie@example.com" should receive a project updated notification
  And the project name should update in their UI without refresh

Scenario: Project deletion notification to workspace members
  Given I am logged in as "alice@example.com"
  And a project exists with name "Old Project" owned by "alice@example.com"
  And user "charlie@example.com" is viewing workspace "product-team"
  When I delete the project
  Then user "charlie@example.com" should receive a project deleted notification
  And the project should be removed from their workspace view
```

### Step Definitions:

```elixir
# Setup: Store LiveView connection for real-time testing
step "user {string} is viewing workspace {string}",
     %{args: [_user_email, _workspace_slug]} = context do
  import Phoenix.LiveViewTest
  
  workspace = context[:workspace]
  conn = context[:conn]
  
  # Subscribe to PubSub to simulate another user watching the workspace
  Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
  
  # Mount and keep the LiveView connection alive for real-time testing
  {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
  
  {:ok,
   context
   |> Map.put(:other_user_viewing_workspace, true)
   |> Map.put(:pubsub_subscribed, true)
   |> Map.put(:workspace_view, view)
   |> Map.put(:last_html, html)}
end

# Tier 1: Verify PubSub broadcast
step "user {string} should receive a project created notification",
     %{args: [_user_email]} = context do
  project = context[:project]
  
  # Verify the PubSub broadcast was received
  assert_receive {:project_added, project_id}, 1000
  assert project_id == project.id
  
  {:ok, context}
end

step "user {string} should receive a project updated notification",
     %{args: [_user_email]} = context do
  project = context[:project]
  
  # Verify the PubSub broadcast was received
  assert_receive {:project_updated, project_id, name}, 1000
  assert project_id == project.id
  assert name == project.name
  
  {:ok, context}
end

step "user {string} should receive a project deleted notification",
     %{args: [_user_email]} = context do
  project = context[:project]
  
  # Verify the PubSub broadcast was received
  assert_receive {:project_removed, project_id}, 1000
  assert project_id == project.id
  
  {:ok, context}
end

# Tier 2: Test LiveView handle_info/2 and UI update
step "the new project should appear in their workspace view", context do
  import Phoenix.LiveViewTest
  
  project = context[:project]
  view = context[:workspace_view]
  
  # Simulate the PubSub message that the LiveView would receive
  # This tests the handle_info/2 callback directly
  send(view.pid, {:project_added, project.id})
  
  # Render the view to see the effects of the PubSub message
  html = render(view)
  
  # Verify the new project appears in the workspace view
  name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
  assert html =~ name_escaped
  
  {:ok, context |> Map.put(:last_html, html)}
end

step "the project name should update in their UI without refresh", context do
  import Phoenix.LiveViewTest
  
  project = context[:project]
  view = context[:workspace_view]
  
  # Simulate the PubSub message that the LiveView would receive
  send(view.pid, {:project_updated, project.id, project.name})
  
  # Render the view to see the effects of the PubSub message
  html = render(view)
  
  # Verify the updated project name appears in the workspace view
  name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
  assert html =~ name_escaped
  
  {:ok, context |> Map.put(:last_html, html)}
end

step "the project should be removed from their workspace view", context do
  import Phoenix.LiveViewTest
  
  project = context[:project]
  view = context[:workspace_view]
  
  # Simulate the PubSub message that the LiveView would receive
  send(view.pid, {:project_removed, project.id})
  
  # Render the view to see the effects of the PubSub message
  html = render(view)
  
  # Verify the deleted project name does NOT appear in the workspace view
  name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
  refute html =~ name_escaped
  
  {:ok, context |> Map.put(:last_html, html)}
end
```

## Message Structures

Document the expected PubSub message formats:

```elixir
# Project messages
{:project_added, project_id}
{:project_updated, project_id, project_name}
{:project_removed, project_id}

# Document visibility changed
{:document_visibility_changed, %{
  document_id: UUID,
  is_public: boolean(),
  changed_by_user_id: UUID
}}

# Document pinned status changed
{:document_pinned_changed, %{
  document_id: UUID,
  is_pinned: boolean(),
  changed_by_user_id: UUID
}}

# Document deleted
{:document_deleted, %{
  document_id: UUID,
  deleted_by_user_id: UUID
}}

# Document updated (title, etc.)
{:document_updated, %{
  document_id: UUID,
  changes: %{title: String.t() | nil}
}}
```

## Testing Checklist

For each PubSub broadcast feature:

- [ ] **Define message structure** - Document expected payload format
- [ ] **Test broadcast is sent** - Verify message is published (Tier 1)
- [ ] **Test message content** - Verify payload contains correct data (Tier 1)
- [ ] **Test topic routing** - Verify message sent to correct topic (Tier 1)
- [ ] **Test LiveView handle_info** - Verify LiveView processes message (Tier 2)
- [ ] **Test UI updates** - Verify UI changes after message received (Tier 2)
- [ ] **Test authorization** - Only authorized users receive messages
- [ ] **Add @javascript test** (optional) - For full end-to-end validation (Tier 3)

## Common Pitfalls

### ❌ Not Storing LiveView Connection

```elixir
# WRONG - LiveView connection is lost
step "user {string} is viewing workspace {string}", context do
  {:ok, _view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
  {:ok, context}  # View is discarded!
end

step "the project should appear in their workspace view", context do
  view = context[:workspace_view]  # nil - no view stored!
  send(view.pid, {:project_added, project.id})  # Will crash!
end
```

### ✅ Store LiveView Connection in Context

```elixir
# CORRECT - Store the view for later use
step "user {string} is viewing workspace {string}", context do
  {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
  {:ok, context |> Map.put(:workspace_view, view)}
end

step "the project should appear in their workspace view", context do
  view = context[:workspace_view]  # View is available!
  send(view.pid, {:project_added, project.id})  # Works!
  html = render(view)
  assert html =~ project.name
end
```

### ❌ Subscribing After Broadcast

```elixir
# WRONG - The broadcast already happened!
step "I create a project", context do
  Projects.create_project(user, workspace.id, %{name: "New Project"})
  {:ok, context}
end

step "user should receive notification", context do
  Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
  assert_receive {:project_added, _}, 1000  # Will timeout!
  {:ok, context}
end
```

### ✅ Subscribe Before Action

```elixir
# CORRECT - Subscribe first, then act
step "user is viewing workspace", context do
  Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
  {:ok, context}
end

step "I create a project", context do
  Projects.create_project(user, workspace.id, %{name: "New Project"})
  {:ok, context}
end

step "user should receive notification", context do
  assert_receive {:project_added, _}, 1000  # Will work!
  {:ok, context}
end
```

### ❌ Wrong Message Pattern

```elixir
# WRONG - Message pattern doesn't match actual broadcast
assert_receive {:created, _}, 1000
```

Check the actual broadcast code to know the correct message format:

```elixir
# In the use case or service
Phoenix.PubSub.broadcast(
  Jarga.PubSub,
  "workspace:#{workspace.id}",
  {:project_added, project.id}
)
```

### ✅ Match Actual Message

```elixir
# CORRECT - Matches the broadcast format
assert_receive {:project_added, project_id}, 1000
```

## Summary

**Best Practices for BDD/Cucumber PubSub Testing:**

1. **Always use Tier 1 (PubSub Verification)** - Verify messages are broadcast correctly
2. **Use Tier 2 (LiveView Testing) for UI updates** - Test handle_info/2 callbacks and UI changes
3. **Subscribe before actions** - PubSub.subscribe in "user is viewing" steps
4. **Store LiveView connections** - Keep view in context for real-time testing
5. **Use send/2 to simulate messages** - Test LiveView's handle_info/2 directly
6. **Verify UI with render/1** - Check that UI updates after message processing
7. **Only use Tier 3 (Wallaby) for JavaScript** - When client-side JS interaction is critical
8. **Document message structures** - Keep message format documentation up-to-date
9. **Use assert_receive with timeout** - 1000ms recommended for PubSub messages

This three-tier approach provides comprehensive PubSub testing while keeping tests fast and maintainable.
