# Cucumber for Elixir v0.4.2 - Complete Documentation

Cucumber is a behavior-driven development (BDD) testing framework for Elixir using Gherkin syntax. It enables developers to write executable specifications in natural language, bridging communication between technical and non-technical team members.

**Source:** https://hexdocs.pm/cucumber/getting_started.html

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Feature Files](#feature-files)
3. [Step Definitions](#step-definitions)
4. [Hooks](#hooks)
5. [Error Handling](#error-handling)
6. [Best Practices](#best-practices)
7. [API Reference](#api-reference)

---

## Getting Started

### Installation

Add to `mix.exs` dependencies:

```elixir
def deps do
  [
    {:cucumber, "~> 0.4.2"}
  ]
end
```

### Test Helper Configuration

Add to `test/test_helper.exs`:

```elixir
ExUnit.start()
Cucumber.compile_features!()
```

### Directory Structure

```
test/
  features/
    user_authentication.feature
    shopping_cart.feature
    step_definitions/
      authentication_steps.exs
      shopping_steps.exs
      common_steps.exs
    support/
      database_support.exs
      hooks.exs
```

### Configuration

Custom paths can be set in `config/test.exs`:

```elixir
config :cucumber,
  features: "test/features/**/*.feature",
  steps: "test/features/step_definitions/**/*.exs"
```

### Running Tests

```bash
mix test                                    # All tests
mix test --only cucumber                    # Cucumber only
mix test --only feature_user_authentication # Specific feature
mix test --exclude cucumber                 # Skip Cucumber tests
```

---

## Feature Files

Feature files are the heart of Cucumber testing. They're written in Gherkin syntax, a business-readable domain-specific language that enables describing application behavior without implementation details.

### Core Components

#### Feature Declaration

Every file begins with the `Feature:` keyword followed by a name and optional description:

```gherkin
Feature: User Authentication
  As a user
  I want to sign in to my account
  So that I can access my personalized content
```

#### Background Section

The `Background:` section contains steps that are executed before each scenario:

```gherkin
Background:
  Given the application is running
  And the database is seeded with test data
```

#### Scenarios

Scenarios provide concrete examples demonstrating expected feature behavior:

```gherkin
Scenario: User signs in with valid credentials
  Given I am on the sign in page
  When I enter "user@example.com" as my email
  And I enter "password123" as my password
  And I click the "Sign In" button
  Then I should be redirected to the dashboard
  And I should see "Welcome back" message
```

### Step Keywords

- `Given`: Sets up preconditions
- `When`: Describes user actions
- `Then`: Specifies expected results
- `And`/`But`: Continues previous step types

### Step Arguments

#### Data Tables

Format tabular information using pipes:

```gherkin
Scenario: Create multiple users
  Given the following users exist:
    | name    | email              | role    |
    | Alice   | alice@example.com  | admin   |
    | Bob     | bob@example.com    | user    |
    | Charlie | charlie@example.com| guest   |
```

#### Doc Strings

Use triple quotes for multiline text:

```gherkin
Scenario: Submit feedback
  When I submit the following feedback:
    """
    This is a detailed feedback message
    that spans multiple lines and includes
    specific details about my experience.
    """
  Then I should see a confirmation message
```

### Tags System

Tags can be applied at feature or scenario levels:

```gherkin
@authentication @smoke
Feature: User Authentication

@async
Scenario: User signs in with valid credentials
  ...

@slow @database
Scenario: User registration with email verification
  ...
```

#### Async Tag

Add `@async` tag for independent features that can run concurrently:

```gherkin
@async
Feature: Calculator Operations

Scenario: Addition
  Given I have numbers 10 and 20
  When I add them together
  Then the result should be 30
```

**Async Constraints:**
- Use only for features that don't share state
- Don't depend on execution order
- Handle concurrent access safely
- Works well with Ecto's SQL sandbox in shared mode

### File Organization

- Place feature files in `test/features/` directory
- Use `.feature` extension
- Use snake_case for file names
- Group related features into subdirectories

---

## Step Definitions

Step definitions connect the Gherkin steps in your feature files to actual code. They serve as the bridge between natural language specifications and implementation code.

### File Organization

- Step definition files use `.exs` extension
- Place in `test/features/step_definitions/` directory
- Each module imports `Cucumber.StepDefinition` and `ExUnit.Assertions`

### Core Syntax

```elixir
defmodule AuthenticationSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions

  step "I am logged in as a customer", context do
    Map.put(context, :user, create_and_login_customer())
  end
end
```

### Parameter Types

#### String Parameters

```elixir
step "I enter {string} as my email", %{args: [email]} = context do
  Map.put(context, :email, email)
end
```

#### Integer Parameters

```elixir
step "I have {int} items in my cart", %{args: [count]} = context do
  Map.put(context, :cart_count, count)
end
```

#### Float Parameters

```elixir
step "the total is {float} dollars", %{args: [amount]} = context do
  assert context.total == amount
  context
end
```

#### Word Parameters

```elixir
step "I am on the {word} page", %{args: [page_name]} = context do
  Map.put(context, :current_page, String.to_atom(page_name))
end
```

#### Multiple Parameters

```elixir
step "I add {int} items of {string} to my cart", %{args: [count, product]} = context do
  context
  |> Map.put(:product, product)
  |> Map.put(:quantity, count)
end
```

### Data Handling

#### Data Tables

Access via `context.datatable`:

```elixir
step "the following users exist:", context do
  for row <- context.datatable.maps do
    create_user(row["name"], row["email"], row["role"])
  end
  context
end
```

#### DocStrings

Access via `context.docstring`:

```elixir
step "I submit the following JSON:", context do
  data = Jason.decode!(context.docstring)
  Map.put(context, :submitted_data, data)
end
```

### Return Values

Valid returns include:
- `:ok` - Success, context unchanged
- `%{} = map` - Success, return new context map
- `{:ok, data}` - Success with data to merge into context
- `{:error, reason}` - Explicit failure

```elixir
step "the operation succeeds" do
  :ok
end

step "I create a user", context do
  user = create_user()
  {:ok, Map.put(context, :user, user)}
end

step "the request fails" do
  {:error, "Expected failure occurred"}
end
```

### Reusable Steps

Create generic steps accepting parameters:

```elixir
# Good - reusable
step "I click the {string} button", %{args: [button_text]} = context do
  click_button(button_text)
  context
end

# Less reusable - hardcoded
step "I click the submit button", context do
  click_button("Submit")
  context
end
```

### Context Usage

Pass data between steps using the context object:

```elixir
step "I create a product named {string}", %{args: [name]} = context do
  product = create_product(name)
  Map.put(context, :product, product)
end

step "I add the product to my cart", context do
  add_to_cart(context.product)
  context
end
```

---

## Hooks

Cucumber for Elixir provides hooks that allow you to run code before and after scenarios. These hooks facilitate setup and teardown operations within test support files located in `test/features/support/`.

### Hook Definition

```elixir
defmodule DatabaseSupport do
  use Cucumber.Hooks

  before_scenario context do
    {:ok, Map.put(context, :setup_done, true)}
  end

  after_scenario _context do
    :ok
  end
end
```

### Before Scenario Hooks

Execute before each scenario:

```elixir
# Global hook - runs for all scenarios
before_scenario context do
  {:ok, Map.put(context, :started_at, DateTime.utc_now())}
end

# Tagged hook - runs only for scenarios with @slow tag
before_scenario "@slow", context do
  {:ok, Map.put(context, :timeout, 30_000)}
end
```

### After Scenario Hooks

Execute after scenarios (run in reverse definition order):

```elixir
after_scenario context do
  cleanup_test_data()
  :ok
end

after_scenario "@database", context do
  Ecto.Adapters.SQL.Sandbox.checkin(Repo)
  :ok
end
```

### Return Values

Hooks accept:
- `:ok` - Success, context unchanged
- `{:ok, map}` - Success with updated context
- `%{} = map` - Success, return new context map
- `{:error, reason}` - Failure

### Execution Order

- Before hooks execute in definition sequence
- After hooks execute in reverse sequence
- Tagged hooks activate only for matching scenario tags
- Global hooks apply universally

### Context Variables

The context includes:
- `:scenario_name` - Name of the current scenario
- `:async` - Whether the scenario is running asynchronously
- `:step_history` - History of executed steps
- Custom data from previous hooks or steps

### Practical Example: Database Setup

```elixir
defmodule DatabaseSupport do
  use Cucumber.Hooks

  before_scenario "@database", context do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)

    if context.async do
      Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
    end

    {:ok, context}
  end

  after_scenario "@database", _context do
    Ecto.Adapters.SQL.Sandbox.checkin(MyApp.Repo)
    :ok
  end
end
```

### Hook Best Practices

- Focus hooks on single responsibilities
- Use tags judiciously
- Minimize side effects
- Ensure cleanup completion
- Leverage context for data sharing

---

## Error Handling

### Enhanced Error Messages

The framework provides:
- **Clickable file:line references** directing to exact feature file locations
- **Contextual information** including feature paths, scenario names, and line numbers
- **Step execution history** showing passed/failed steps before failure
- **Improved formatting** for assertion errors and HTML elements

### Error Types

#### Missing Step Definition

When a step lacks a matching definition, you receive guidance showing the exact step text and a code template for implementation:

```
Step not found: "I click the login button"

You can implement this step with:

  step "I click the login button", context do
    # Your implementation here
    context
  end
```

#### Failed Step

Failures display comprehensive information:
- The failed step text
- Matching pattern
- Error messages
- Visual step history (✓/✗ indicators)
- Full stack traces

#### Assertion Error Formatting

ExUnit assertion failures are extracted and reformatted for readability:

```
Expected: "Welcome"
Actual: "Error"
```

### Step Failure Methods

Steps fail through:
1. **Assertions** - ExUnit assertions that fail
2. **Raising Exceptions** - Uncaught exceptions
3. **Error Tuples** - Explicit `{:error, reason}` returns

### Debugging Strategies

- Click file references to navigate directly to failures
- Review step history to understand execution flow
- Use `IO.inspect()` for variable examination
- Add logging for step execution tracking
- Examine accumulated context state
- Create debug-specific steps for investigation
- Implement retry logic for timing-sensitive tests

### Common Error Patterns

| Error | Cause | Solution |
|-------|-------|----------|
| Step not found | Missing or mismatched step definition | Check spelling, add step definition |
| Assertion failed | Expected value doesn't match actual | Review test data and expectations |
| Timeout | Operation took too long | Increase timeout or optimize operation |
| Element not found | UI element doesn't exist | Check selectors, wait for element |
| Context key missing | Required data not in context | Ensure previous steps set the data |

---

## Best Practices

### Writing Good Scenarios

#### Key Principles

1. **Each scenario should test one specific behavior**
2. Maintain consistent language throughout
3. Use concrete examples rather than placeholders
4. Avoid technical jargon
5. Keep scenarios between 3-7 steps
6. Use backgrounds judiciously

#### Bad vs. Good Examples

**Bad:**
```gherkin
Scenario: User does stuff
  Given the user exists
  When the user does stuff
  Then stuff happens
```

**Good:**
```gherkin
Scenario: Customer adds product to shopping cart
  Given I am logged in as a customer
  And a product "Blue Widget" exists with price "$29.99"
  When I add "Blue Widget" to my cart
  Then I should see "Blue Widget" in my cart
  And the cart total should be "$29.99"
```

### Step Definition Best Practices

#### Reusability

Create generic steps accepting parameters:

```elixir
# Good - reusable
step "I fill in {string} with {string}", %{args: [field, value]} = context do
  fill_in(field, value)
  context
end

# Less reusable
step "I fill in the email field with test@example.com", context do
  fill_in("email", "test@example.com")
  context
end
```

#### Organization

Group related steps within the same module:

```elixir
defmodule AuthenticationSteps do
  use Cucumber.StepDefinition
  # All authentication-related steps here
end

defmodule ShoppingCartSteps do
  use Cucumber.StepDefinition
  # All shopping cart-related steps here
end
```

### Common Patterns

#### Data Setup with Helpers

```elixir
defp create_user(attrs \\ %{}) do
  default_attrs = %{
    name: "Test User",
    email: "test@example.com",
    password: "password123"
  }

  MyApp.Accounts.create_user(Map.merge(default_attrs, attrs))
end
```

#### Assertion Helpers

```elixir
defp assert_logged_in(context) do
  assert context.session != nil
  assert context.current_user != nil
  context
end
```

### Testing Tips

#### Tags for Filtering

```gherkin
@authentication @smoke
Feature: User Authentication
```

```bash
mix test --only authentication
mix test --only smoke
```

#### Backgrounds vs. Helpers

- **Backgrounds:** Universal setup affecting all scenarios
- **Helper steps:** Scenario-specific initialization

#### Asynchronous Operations

Implement polling mechanisms with timeouts:

```elixir
step "I should receive an email within {int} seconds", %{args: [timeout]} = context do
  wait_for(timeout * 1000, fn ->
    check_for_email(context.user.email)
  end)
  context
end

defp wait_for(timeout, check_fn, interval \\ 100) do
  start = System.monotonic_time(:millisecond)
  do_wait_for(timeout, check_fn, interval, start)
end

defp do_wait_for(timeout, check_fn, interval, start) do
  if check_fn.() do
    :ok
  else
    elapsed = System.monotonic_time(:millisecond) - start
    if elapsed >= timeout do
      flunk("Timeout waiting for condition")
    else
      Process.sleep(interval)
      do_wait_for(timeout, check_fn, interval, start)
    end
  end
end
```

### Debugging Tips

- Use clickable file:line references in error messages
- Review visual execution history showing passed/failed steps
- Use `IO.inspect()` for variable inspection
- Run single scenarios during debugging
- Include context in assertion messages

---

## API Reference

### Cucumber Module

The main module for compiling and running Cucumber tests.

#### compile_features!/1

```elixir
Cucumber.compile_features!(opts \\ [])
```

Discovers and compiles all Cucumber features into ExUnit tests. Add to `test/test_helper.exs`.

**Options:**
- `:features` - Path pattern for feature files (default: `"test/features/**/*.feature"`)
- `:steps` - Path pattern for step definitions (default: `"test/features/step_definitions/**/*.exs"`)

### Cucumber.StepDefinition Module

Provides macros for defining cucumber step definitions.

#### step/3 macro

```elixir
step pattern, context \\ quote(do: _), do: block
```

Defines a step implementation.

**Parameters:**
- `pattern` - The step pattern to match (supports `{string}`, `{int}`, `{float}`, `{word}`)
- `context` - The context variable (optional, defaults to `_`)
- `block` - The implementation

**Example:**
```elixir
step "I am logged in as {string}", %{args: [username]} = context do
  {:ok, Map.put(context, :current_user, username)}
end
```

### Cucumber.Expression Module

Parser and matcher for Cucumber Expressions.

#### Supported Parameter Types

- `{string}` - Quoted strings → string
- `{int}` - Integer values → integer
- `{float}` - Decimal numbers → float
- `{word}` - Single words → string

#### compile/1

```elixir
Cucumber.Expression.compile(pattern)
```

Transforms a pattern into a regex with conversion functions.

#### match/2

```elixir
Cucumber.Expression.match(text, compiled_expression)
```

Attempts to match step text against a compiled expression.

Returns `{:match, args}` or `:no_match`.

### Cucumber.Hooks Module

Provides setup and teardown capabilities.

#### before_scenario/2 and before_scenario/3

```elixir
before_scenario context do
  # Global hook
end

before_scenario "@tag", context do
  # Tagged hook
end
```

#### after_scenario/2 and after_scenario/3

```elixir
after_scenario context do
  # Global cleanup
end

after_scenario "@tag", context do
  # Tagged cleanup
end
```

### Cucumber.Runtime Module

Handles runtime execution of cucumber steps.

#### execute_step/3

```elixir
Cucumber.Runtime.execute_step(context, step, step_registry)
```

Executes a step within the given context using the step registry.

### Gherkin.Parser Module

Minimal Gherkin 6 parser.

#### parse/1

```elixir
Gherkin.Parser.parse(gherkin_string)
```

Converts Gherkin syntax strings into structured data.

**Returns:** `%Gherkin.Feature{}` struct containing:
- `name` - Feature identifier
- `description` - Feature details
- `tags` - Feature-level tags
- `background` - Background steps (optional)
- `scenarios` - Scenario collection

### Other Modules

- **Cucumber.Compiler** - Transforms discovered features and steps into ExUnit test modules
- **Cucumber.Discovery** - Identifies and loads feature files and step definitions
- **Cucumber.StepError** - Exception raised when a step fails
- **Gherkin.Background** - Represents a Gherkin Background section
- **Gherkin.Feature** - Represents a parsed Gherkin feature file
- **Gherkin.Scenario** - Represents a Gherkin Scenario section
- **Gherkin.Step** - Represents a Gherkin step (Given/When/Then/And/But/*)

---

## Resources

- **Hex Package:** https://hex.pm/packages/cucumber
- **GitHub:** https://github.com/huddlz-hq/cucumber
- **HexDocs:** https://hexdocs.pm/cucumber
