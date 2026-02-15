# Feature Testing Guide

> **Official Documentation**: [Cucumber for Elixir - Getting Started](https://hexdocs.pm/cucumber/getting_started.html#overview)

## Philosophy

Feature tests in Jarga are **full-stack integration tests** that verify the entire application stack from HTTP request to HTML response. These tests are NOT backend-focused unit tests.

### Key Principles

1. **Full Stack Testing** - Test the entire request/response cycle
2. **HTML Assertions** - Always inspect rendered HTML, never test backend in isolation
3. **Selective JavaScript** - Only use Wallaby for `@javascript` tagged scenarios
4. **Mock 3rd Parties** - Mock external services (LLMs, payment providers, etc.) with Mox
5. **Real Database** - Use real database with Ecto Sandbox (not mocked)

## Test Types

### Cucumber Feature Tests (`test/features/*.feature`)

**Purpose**: Business-facing acceptance tests written in Gherkin

**When to use**:

- Complex user workflows
- Permission matrices
- Multi-step business processes
- Documentation of business requirements

**Technology**:

- Non-JavaScript scenarios: `ConnCase` + `Phoenix.LiveViewTest`
- JavaScript scenarios: `Wallaby` (browser automation)

**Example**:

```gherkin
Scenario: Member creates a document in workspace
  Given I am logged in as "charlie@example.com"
  When I create a document with title "Meeting Notes" in workspace "product-team"
  Then the document should be created successfully
  And I should see "Meeting Notes" in the document list
```

### Traditional Integration Tests (`test/jarga_web/features/*_test.exs`)

**Purpose**: Technical integration tests for complex UI interactions

**When to use**:

- Rich text editor features (undo/redo, markdown)
- Real-time collaboration
- Complex UI state machines
- Performance-sensitive interactions

**Technology**:

- Always use `Wallaby` for these (they need real browser)
- Tagged with `@tag :javascript`

**Example**:

```elixir
@tag :javascript
test "undo and redo in editor", %{session: session} do
  session
  |> visit("/app/workspace/document")
  |> fill_in(Query.css("#editor"), with: "Hello World")
  |> send_keys([:control, "z"])  # Undo
  |> assert_has(Query.css("#editor", text: ""))
end
```

## Cucumber Step Definitions

> **Reference**: Using the [new Cucumber.StepDefinition API](https://hexdocs.pm/cucumber/getting_started.html#step-definitions) (v0.4+)

### Structure

Step definitions live in `test/features/step_definitions/*_steps.exs`:

```elixir
defmodule DocumentSteps do
  use Cucumber.StepDefinition  # New API (v0.4+)
  use JargaWeb.ConnCase        # For non-JavaScript scenarios

  import Phoenix.LiveViewTest

  # Steps use `step "pattern", %{args: [...]} = context do`
  step "I am logged in as {string}", %{args: [email]} = context do
    user = get_user_by_email(email)
    conn = build_conn() |> log_in_user(user)

    {:ok, context |> Map.put(:conn, conn) |> Map.put(:user, user)}
  end
end
```

### Step Definition Syntax

**Pattern Matching**:

- `{string}` - Matches quoted strings: `"hello"`
- `{int}` - Matches integers: `42` (also used for numeric assertions including floats)
- `{word}` - Matches single word: `admin`

**Context Parameter**:

```elixir
step "I create a document with title {string}", %{args: [title]} = context do
  # args[0] contains the matched string
  # context contains state from previous steps

  user = context[:current_user]
  conn = context[:conn]

  # Return updated context
  {:ok, Map.put(context, :document, document)}
end
```

### ConnCase vs Wallaby

**Use ConnCase** (default):

```elixir
defmodule MySteps do
  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest

  step "I click {string}", %{args: [button_text]} = context do
    {:ok, view, _html} = live(context[:conn], ~p"/app/documents")

    html = view
    |> element("button", button_text)
    |> render_click()

    {:ok, Map.put(context, :last_html, html)}
  end
end
```

**Use Wallaby** (only for @javascript):

```elixir
defmodule CollaborationSteps do
  use Cucumber.StepDefinition
  use JargaWeb.FeatureCase

  step "I type in the editor", context do
    session = context[:session]

    session
    |> fill_in(Query.css("#editor"), with: "Hello")
    |> assert_has(Query.css("#editor", text: "Hello"))

    {:ok, context}
  end
end
```

## Data Tables

Gherkin data tables allow you to pass structured data to steps:

### Feature File

```gherkin
Scenario: User sees filtered documents
  Given I am logged in as "alice@example.com"
  And the following documents exist in workspace "product-team":
    | Title           | Owner              | Visibility |
    | Team Guidelines | alice@example.com  | Public     |
    | Private Notes   | alice@example.com  | Private    |
    | Meeting Notes   | bob@example.com    | Public     |
  When I list all documents
  Then I should see "Team Guidelines"
  And I should see "Meeting Notes"
```

### Step Definition with Data Table

```elixir
step "the following documents exist in workspace {string}:",
     %{args: [workspace_slug]} = context do
  workspace = context[:workspace]
  users = context[:users]

  # Access data table using dot notation
  table_data = context.datatable.maps
  # Returns: [
  #   %{"Title" => "Team Guidelines", "Owner" => "alice@example.com", "Visibility" => "Public"},
  #   %{"Title" => "Private Notes", "Owner" => "alice@example.com", "Visibility" => "Private"},
  #   ...
  # ]

  # Process each row
  documents =
    Enum.map(table_data, fn row ->
      owner = users[row["Owner"]]

      document_fixture(owner, workspace, nil, %{
        title: row["Title"],
        is_public: row["Visibility"] == "Public"
      })
    end)

  # Return context directly (no {:ok, }) for data table steps
  Map.put(context, :documents, documents)
end
```

### Data Table API

```elixir
# Access headers
headers = context.datatable.headers
# Returns: ["Title", "Owner", "Visibility"]

# Access rows as maps (most common)
maps = context.datatable.maps
# Returns: [%{"Title" => "...", "Owner" => "...", ...}, ...]

# Access raw rows (less common)
rows = context.datatable.rows
# Returns: [["Team Guidelines", "alice@example.com", "Public"], ...]
```

### Important: Return Format for Data Tables

**Data table steps return context directly** (without `{:ok, }`):

```elixir
# ✅ CORRECT - Return context directly
step "the following items exist:", context do
  items = process_table(context.datatable.maps)
  Map.put(context, :items, items)
end

# ❌ WRONG - Don't wrap in {:ok, }
step "the following items exist:", context do
  items = process_table(context.datatable.maps)
  {:ok, Map.put(context, :items, items)}  # DON'T DO THIS
end
```

**Regular steps (without data tables) use `{:ok, context}`**:

```elixir
# ✅ CORRECT - Regular steps return {:ok, context}
step "I create a document with title {string}", %{args: [title]} = context do
  document = create_document(title)
  {:ok, Map.put(context, :document, document)}
end
```

## HTML Assertions

### Always Assert on HTML

**❌ WRONG - Backend only**:

```elixir
step "the document should be created", context do
  assert context[:document] != nil
  {:ok, context}
end
```

**✅ RIGHT - Full stack**:

```elixir
step "the document should be created", context do
  # Check database
  assert context[:document] != nil

  # Check HTML rendering
  html = context[:last_html]
  assert html =~ context[:document].title
  assert html =~ "Document created successfully"

  {:ok, context}
end
```

### HTML Encoding for Special Characters

When testing titles or content with special characters (`&`, `<`, `>`, quotes), remember that HTML entities are encoded:

```elixir
step "I create a document with title {string}", %{args: [title]} = context do
  # title = "Product & Services (2024)"

  result = Documents.create_document(user, workspace.id, %{title: title})

  case result do
    {:ok, document} ->
      {:ok, _view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # ❌ WRONG - Won't find "Product & Services (2024)"
      # assert html =~ title

      # ✅ RIGHT - Encode special characters for HTML
      html_encoded_title = Phoenix.HTML.html_escape(title) |> Phoenix.HTML.safe_to_string()
      assert html =~ html_encoded_title  # Matches "Product &amp; Services (2024)"

      {:ok, Map.put(context, :document, document)}
  end
end
```

**Common HTML Entities**:

- `&` becomes `&amp;`
- `<` becomes `&lt;`
- `>` becomes `&gt;`
- `"` becomes `&quot;`
- `'` becomes `&#39;`

### LiveView Testing Patterns

**Mount and render**:

```elixir
step "I view the document list", context do
  {:ok, view, html} = live(context[:conn], ~p"/app/workspaces/#{context[:workspace].slug}/documents")

  assert html =~ "Documents"

  {:ok, context |> Map.put(:view, view) |> Map.put(:last_html, html)}
end
```

**Click buttons**:

```elixir
step "I click {string}", %{args: [button_text]} = context do
  html = context[:view]
  |> element("button", button_text)
  |> render_click()

  assert html =~ "Create Document"

  {:ok, Map.put(context, :last_html, html)}
end
```

**Submit forms**:

```elixir
step "I submit the document form", context do
  document = context[:document]

  html = context[:view]
  |> form("#document-form", document: %{title: document.title})
  |> render_submit()

  assert html =~ "Document created"

  {:ok, Map.put(context, :last_html, html)}
end
```

**Navigate to LiveView routes**:

```elixir
step "I view document {string} in workspace {string}",
     %{args: [title, workspace_slug]} = context do
  workspace = context[:workspace]
  document = context[:document]

  # Use verified route helper with full path
  {:ok, view, html} =
    live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

  {:ok, context |> Map.put(:view, view) |> Map.put(:last_html, html)}
end
```

### Wallaby Testing Patterns

**Navigate and interact**:

```elixir
@tag :javascript
defwhen ~r/^I navigate to documents$/, _vars, state do
  session = state[:session]

  session
  |> visit("/app/documents")
  |> assert_has(Query.text("Documents"))

  {:ok, state}
end
```

**Fill forms**:

```elixir
@tag :javascript
defwhen ~r/^I create a document$/, _vars, state do
  session = state[:session]

  session
  |> click(Query.button("New Document"))
  |> fill_in(Query.text_field("Title"), with: "My Doc")
  |> click(Query.button("Create"))
  |> assert_has(Query.text("Document created"))

  {:ok, state}
end
```

## Mocking External Services

### Setup Mocks

In `test/test_helper.exs`:

```elixir
Mox.defmock(Jarga.LlmClientMock, for: Jarga.LlmClientBehaviour)
```

### Use in Tests

```elixir
defgiven ~r/^the AI service is available$/, _vars, state do
  Mox.expect(Jarga.LlmClientMock, :complete, fn _prompt ->
    {:ok, "AI generated response"}
  end)

  {:ok, state}
end
```

### What to Mock

**Mock**:

- LLM APIs (OpenAI, Anthropic)
- Payment providers (Stripe)
- Email services (SendGrid, Postmark)
- External APIs (GitHub, Slack)

**Don't Mock**:

- Database (use real DB with Ecto Sandbox)
- Phoenix framework (use real LiveView/conn)
- Internal application code (test real implementations)

## State Management

Cucumber maintains state between steps in a context map that flows through all steps:

```elixir
# Initialize context
step "I am logged in as {string}", %{args: [email]} = _context do
  user = user_fixture(%{email: email})
  conn = build_conn() |> log_in_user(user)

  {:ok, %{user: user, current_user: user, conn: conn}}
end

# Read context from previous steps
step "I create a document with title {string}", %{args: [title]} = context do
  conn = context[:conn]        # Get conn from previous step
  user = context[:current_user] # Get user from previous step
  workspace = context[:workspace]

  result = Documents.create_document(user, workspace.id, %{title: title})
  # ... rest of step
end

# Update context for next steps
step "the document should be created", context do
  document = context[:document]

  {:ok, Map.put(context, :document_created, true)}
end
```

### Context Conventions

**Standard keys**:

- `context[:conn]` - Current Phoenix connection
- `context[:current_user]` - Currently logged in user
- `context[:users]` - Map of all users by email: `%{"alice@example.com" => %User{}}`
- `context[:workspace]` - Current workspace
- `context[:workspace_owner]` - Owner of current workspace
- `context[:project]` - Current project
- `context[:document]` - Current document
- `context[:last_html]` - Last rendered HTML from LiveView
- `context[:last_result]` - Last operation result (for error checking)
- `context[:view]` - Current LiveView test view
- `context[:session]` - Wallaby session (for `@javascript` scenarios)

**Data table keys**:

- `context.datatable` - Data table from step (use dot notation, not bracket)
- `context.datatable.maps` - Rows as list of maps
- `context.datatable.headers` - Column headers
- `context.datatable.rows` - Raw rows as lists

## Database Setup (Ecto Sandbox)

Cucumber tests must properly manage database transactions using Ecto Sandbox:

### Background Steps Setup

The **first Background step** must checkout the Ecto Sandbox:

```elixir
# In test/features/step_definitions/common_steps.exs

step "a workspace exists with name {string} and slug {string}",
     %{args: [name, slug]} = context do
  # First step in Background - checkout sandbox
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Jarga.Repo)
  Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, {:shared, self()})

  # Now safe to access database
  owner = user_fixture()
  workspace = workspace_fixture(owner, %{name: name, slug: slug})

  {:ok, %{workspace: workspace, workspace_owner: owner}}
end
```

### Hooks (After Background)

Cucumber hooks run **after** Background steps, so they can't set up the sandbox:

```elixir
# In test/features/support/hooks.exs
defmodule CucumberHooks do
  use Cucumber.Hooks

  before_scenario context do
    # This runs AFTER Background, so check if already checked out
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})
      {:already, _owner} ->
        # Background already checked out - this is normal
        :ok
    end

    {:ok, context}
  end
end
```

### Why This Matters

```gherkin
Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  # ☝️ This Background step runs BEFORE hooks
  # It MUST checkout sandbox or database queries will fail

Scenario: Create document
  Given I am logged in as "alice@example.com"
  # This step runs AFTER hooks and can assume sandbox is ready
```

## Error Handling

### Expected Errors

```elixir
step "I should receive a forbidden error", context do
  # Check the result
  case context[:last_result] do
    {:error, :forbidden} ->
      {:ok, context}
    _ ->
      flunk("Expected {:error, :forbidden}, got: #{inspect(context[:last_result])}")
  end
end

step "I should see an error message", context do
  html = context[:last_html]

  # Verify error message is displayed to user
  assert html =~ "You don't have permission" or
         html =~ "Access denied" or
         html =~ "error"

  {:ok, context}
end
```

### Error Handling with LiveView

```elixir
step "I attempt to view document {string}", %{args: [title]} = context do
  workspace = context[:workspace]
  document = context[:document]

  # Try to access - may raise or redirect
  try do
    {:ok, _view, html} =
      live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok, Map.put(context, :last_html, html) |> Map.put(:last_error, nil)}
  rescue
    error ->
      # Store error for assertion
      {:ok, Map.put(context, :last_error, error)}
  end
end

step "I should receive a document not found error", context do
  # Check if error was raised or result was error
  case {context[:last_error], context[:last_result]} do
    {nil, {:error, :document_not_found}} -> {:ok, context}
    {%_{}, _} -> {:ok, context}  # Any error struct
    _ -> flunk("Expected document not found error")
  end
end
```

## Testing Checklist

### For Every Scenario

- [ ] Does it test the full stack (HTTP → HTML)?
- [ ] Does it inspect rendered HTML?
- [ ] Are 3rd party services mocked?
- [ ] Does it use Wallaby only if tagged `@javascript`?
- [ ] Does it use real database with Ecto Sandbox?
- [ ] Does it verify authorization (not just functionality)?
- [ ] Does context flow correctly between steps?

### For Every Step Definition

- [ ] Uses `Cucumber.StepDefinition` API (not old regex API)
- [ ] Parameter is named `context` (not `state` or `vars`)
- [ ] Returns `{:ok, context}` for regular steps
- [ ] Returns `Map.put(context, :key, value)` for data table steps
- [ ] HTML assertions use `Phoenix.HTML.html_escape` for special characters
- [ ] Routes match exact patterns from `router.ex`
- [ ] Schema fields match actual Ecto schema definitions
- [ ] First Background step sets up Ecto Sandbox

### For Data Table Steps

- [ ] Access via `context.datatable.maps` (dot notation)
- [ ] Return context directly: `Map.put(context, :items, items)`
- [ ] No `{:ok, }` wrapper on return value
- [ ] Process all rows from table
- [ ] Column names match feature file headers exactly

## Common Pitfalls

### ❌ Testing Backend Only

```elixir
# WRONG - Only tests backend
defthen ~r/^document exists$/, _vars, state do
  document = Documents.get_document(id)
  assert document != nil
  {:ok, state}
end
```

### ✅ Testing Full Stack

```elixir
# RIGHT - Tests backend AND rendering
defthen ~r/^document exists$/, _vars, state do
  # Backend check
  document = Documents.get_document(id)
  assert document != nil

  # Frontend check
  {:ok, _view, html} = live(state[:conn], ~p"/documents")
  assert html =~ document.title

  {:ok, Map.put(state, :document, document)}
end
```

### ❌ Using Wallaby Unnecessarily

```elixir
# WRONG - Wallaby for simple form submission
@tag :javascript
defwhen ~r/^I submit form$/, _vars, state do
  session = state[:session]
  session |> click(Query.button("Submit"))
  {:ok, state}
end
```

### ✅ Using LiveViewTest for Forms

```elixir
# RIGHT - LiveViewTest is faster and sufficient
defwhen ~r/^I submit form$/, _vars, state do
  html = state[:view]
  |> form("#my-form")
  |> render_submit()

  {:ok, Map.put(state, :html, html)}
end
```

## Example: Complete Feature Test Flow

```gherkin
Scenario: User creates and edits document
  Given I am logged in as "alice@example.com"
  And a workspace "Engineering" exists
  When I visit the documents page
  And I click "New Document"
  And I fill in title with "API Design"
  And I submit the form
  Then I should see "Document created"
  And I should see "API Design" in the list
  When I click "Edit"
  And I update the title to "REST API Design"
  And I save the changes
  Then I should see "Document updated"
  And I should see "REST API Design"
```

Step definitions:

```elixir
defmodule DocumentSteps do
  use Cucumber.StepDefinition  # New API
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest

  step "I am logged in as {string}", %{args: [email]} = _context do
    user = user_fixture(%{email: email})
    conn = build_conn() |> log_in_user(user)
    {:ok, %{conn: conn, current_user: user}}
  end

  step "a workspace {string} exists", %{args: [name]} = context do
    workspace = workspace_fixture(%{name: name})
    {:ok, Map.put(context, :workspace, workspace)}
  end

  step "I visit the documents page", context do
    workspace = context[:workspace]
    {:ok, view, html} = live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents")

    assert html =~ "Documents"

    {:ok, context |> Map.put(:view, view) |> Map.put(:last_html, html)}
  end

  step "I click {string}", %{args: [text]} = context do
    html = context[:view]
    |> element("button", text)
    |> render_click()

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I fill in title with {string}", %{args: [value]} = context do
    # Store for later form submission
    attrs = Map.get(context, :form_attrs, %{})
    {:ok, Map.put(context, :form_attrs, Map.put(attrs, :title, value))}
  end

  step "I submit the form", context do
    html = context[:view]
    |> form("#document-form", document: context[:form_attrs])
    |> render_submit()

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I should see {string}", %{args: [text]} = context do
    # HTML-encode the text to match rendered output
    html_text = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()
    assert context[:last_html] =~ html_text
    {:ok, context}
  end
end
```

## Common Gotchas and Best Practices

### ✅ Route Patterns Must Match Router

Always use **full route paths** that match your `router.ex`:

```elixir
# ❌ WRONG - Shortened path
live(conn, ~p"/app/#{workspace.slug}/documents/#{document.slug}")

# ✅ RIGHT - Full path matching router
live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")
```

Check your `router.ex` to verify the exact path pattern.

### ✅ Schema Fields Must Match Entities

Use **actual field names** from your Ecto schemas:

```elixir
# ❌ WRONG - Field doesn't exist
document_fixture(owner, workspace, nil, %{visibility: :private})

# ✅ RIGHT - Matches schema field
document_fixture(owner, workspace, nil, %{is_public: false})
```

### ✅ Data Table Return Format

**Data table steps** return context directly:

```elixir
step "the following documents exist:", context do
  documents = process_table(context.datatable.maps)
  Map.put(context, :documents, documents)  # No {:ok, }
end
```

**Regular steps** wrap in `{:ok, }`:

```elixir
step "I create a document", context do
  document = create_document()
  {:ok, Map.put(context, :document, document)}  # Wrap in {:ok, }
end
```

### ✅ HTML Entity Encoding

Test assertions must account for HTML encoding:

```elixir
# Title: "Product & Services"
# Rendered as: "Product &amp; Services"

html_title = Phoenix.HTML.html_escape(title) |> Phoenix.HTML.safe_to_string()
assert html =~ html_title
```

### ✅ Ecto Sandbox in Background

The **first Background step** must set up the database:

```elixir
step "a workspace exists with name {string}", %{args: [name]} = _context do
  # First step - checkout sandbox
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Jarga.Repo)
  Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, {:shared, self()})

  # Now safe to query
  workspace = workspace_fixture(%{name: name})
  {:ok, %{workspace: workspace}}
end
```

### ✅ Context Parameter Name

Always use `context` (not `state`, `vars`, etc.):

```elixir
# ✅ CORRECT
step "I do something", context do
  user = context[:current_user]
  {:ok, context}
end

# ❌ WRONG - Parameter name matters
step "I do something", state do  # Don't use 'state'
  {:ok, state}
end
```

## Running Tests

### All Feature Tests

```bash
mix test test/features/
```

### Specific Feature

```bash
mix test test/features/documents.feature
```

### Specific Scenario (by line number)

```bash
mix test test/features/documents.feature:16
```

### Include JavaScript Tests

```bash
mix test --include wallaby test/features/
```

### Watch Mode

```bash
mix test.watch test/features/
```

## Summary

- Feature tests are **full-stack integration tests**
- Always **inspect rendered HTML**, never test backend in isolation
- Use **ConnCase + LiveViewTest** by default
- Use **Wallaby** only for `@javascript` scenarios
- **Mock 3rd party services**, use real database
- Tests verify the **entire user experience** from request to rendered page
