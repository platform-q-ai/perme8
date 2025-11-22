# Test-Driven Development (TDD)

**This project follows a strict Test-Driven Development approach.**

## Overview

Test-Driven Development is a software development methodology where tests are written before implementation code. This ensures better designed, more testable code with complete test coverage, living documentation, confidence in refactoring, and fewer bugs in production.

## The TDD Cycle: Red-Green-Refactor

Follow this cycle for all new code:

### 1. Red: Write a Failing Test

- Start by writing a test that describes the desired behavior
- Run the test and confirm it fails (RED)
- The test should fail for the right reason (e.g., function doesn't exist, wrong behavior)

### 2. Green: Make the Test Pass

- Write the minimal code needed to make the test pass
- Don't worry about perfect design at this stage
- Focus on making the test GREEN as quickly as possible

### 3. Refactor: Improve the Code

- Clean up the code while keeping tests green
- Apply SOLID principles and design patterns
- Remove duplication and improve naming
- Tests provide safety net for refactoring

## TDD Best Practices

### Always Write Tests First

- **Before writing any production code**, write the test
- Resist the temptation to write code first and test later
- Tests written first are better designed and more focused

### Start with the Simplest Test

- Begin with the easiest case (happy path)
- Add edge cases and error cases incrementally
- Build complexity gradually

### One Test at a Time

- Write one test, make it pass, then write the next
- Don't write multiple failing tests at once
- Commit after each green cycle if possible

### Test Behavior, Not Implementation

- Focus on **what** the code should do, not **how**
- Tests should not break when refactoring internal implementation
- Test the public API, not private functions

### Keep Tests Fast

- Domain tests should run in milliseconds (no I/O)
- Use mocks/stubs for external dependencies
- Reserve integration tests for critical paths only
- Fast tests encourage running them frequently

### Make Tests Readable

- Use descriptive test names that explain the scenario
- Follow Arrange-Act-Assert pattern
- One assertion per test when possible
- Use setup blocks to reduce duplication

## TDD Workflow Example

When implementing a new feature:

**Example Request:** "Add a feature to calculate shipping costs based on weight and distance"

**TDD Response:**

### 1. Start with Domain Tests

`test/my_app/domain/shipping_calculator_test.exs`:

```elixir
test "calculates shipping for 5kg over 100km"
test "calculates shipping for 1kg over 50km"
test "returns error for negative weight"
```

### 2. Implement Domain Logic

`lib/my_app/domain/shipping_calculator.ex`

### 3. Add Use Case Tests

`test/my_app/application/calculate_shipping_test.exs`:

```elixir
test "calculates shipping and applies user discount"
test "returns error when user not found"
```

### 4. Implement Use Case

`lib/my_app/application/calculate_shipping.ex`

### 5. Add Controller/LiveView Tests

`test/my_app_web/live/shipping_live_test.exs`:

```elixir
test "displays calculated shipping cost"
test "shows error message for invalid input"
```

### 6. Implement UI

`lib/my_app_web/live/shipping_live.ex`

## Testing Strategy

### Test Pyramid

Follow the test pyramid - more tests at the bottom, fewer at the top:

```
        /\
       /  \      Few: UI/Integration Tests
      /----\
     /      \    More: Use Case Tests
    /--------\
   /          \  Most: Domain Tests (Fast, Pure Logic)
  /------------\
```

### Testing by Layer (TDD Order)

#### 1. Domain Layer (Start Here)

- Write tests first using `ExUnit.Case`
- No database, no external dependencies
- Pure logic testing - fastest tests
- Tests should run in milliseconds
- Test edge cases and business rules thoroughly

**Example:**
```elixir
defmodule MyApp.Domain.ShippingCalculatorTest do
  use ExUnit.Case, async: true

  alias MyApp.Domain.ShippingCalculator

  describe "calculate/2" do
    test "calculates shipping for 5kg over 100km" do
      assert {:ok, cost} = ShippingCalculator.calculate(5, 100)
      assert cost == 50.0
    end

    test "returns error for negative weight" do
      assert {:error, :invalid_weight} = ShippingCalculator.calculate(-1, 100)
    end
  end
end
```

#### 2. Application Layer (Use Cases)

- Write tests first using `MyApp.DataCase`
- Use Mox for external dependencies
- Test orchestration and workflows
- Mock infrastructure services
- Test transaction boundaries

**Example:**
```elixir
defmodule MyApp.Application.CalculateShippingTest do
  use MyApp.DataCase, async: true

  import Mox

  alias MyApp.Application.CalculateShipping

  describe "execute/2" do
    test "calculates shipping and applies user discount" do
      user = insert(:user, discount: 0.1)

      assert {:ok, %{cost: cost}} = CalculateShipping.execute(user.id, weight: 5, distance: 100)
      assert cost == 45.0  # 50.0 with 10% discount
    end
  end
end
```

#### 3. Infrastructure Layer

- Write tests first using `MyApp.DataCase`
- Integration tests with real database
- Test queries, repos, and external services
- Use database sandbox for isolation
- Keep these tests fast but thorough

**Example:**
```elixir
defmodule MyApp.Infrastructure.ShipmentRepositoryTest do
  use MyApp.DataCase, async: true

  alias MyApp.Infrastructure.ShipmentRepository

  describe "create/1" do
    test "creates a shipment record" do
      attrs = %{weight: 5, distance: 100, cost: 50.0}

      assert {:ok, shipment} = ShipmentRepository.create(attrs)
      assert shipment.weight == 5
    end
  end
end
```

#### 4. Interface Layer (Last)

- Write tests first using `MyAppWeb.ConnCase`
- Test controllers and LiveViews
- Test HTTP concerns (status, redirects, rendering)
- Mock or use test doubles for business logic
- Focus on user interactions and UI state

**Example:**
```elixir
defmodule MyAppWeb.ShippingLiveTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "shipping calculator" do
    test "displays calculated shipping cost", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/shipping")

      view
      |> form("#shipping-form", %{weight: 5, distance: 100})
      |> render_submit()

      assert render(view) =~ "Cost: $50.00"
    end
  end
end
```

## Test Organization

```
test/
├── my_app/
│   ├── domain/              # Pure unit tests (write first)
│   │   └── *_test.exs
│   ├── application/         # Use case tests with mocks
│   │   └── *_test.exs
│   └── infrastructure/      # Integration tests
│       └── *_test.exs
├── my_app_web/
│   ├── controllers/         # HTTP tests
│   │   └── *_test.exs
│   └── live/                # LiveView tests
│       └── *_test.exs
└── support/
    ├── fixtures/            # Test data builders
    ├── conn_case.ex
    └── data_case.ex
```

## Running Tests During TDD

```bash
# Run tests continuously (recommended during TDD)
mix test.watch

# Run specific test
mix test path/to/test.exs:line_number

# Run all tests before committing
mix test

# Run tests with coverage
mix test --cover
```

### Performance Guidelines

- Keep tests fast - entire suite should run in seconds
- Use `async: true` when tests don't share state
- Domain tests should run in milliseconds
- Integration tests should still be reasonably fast

## Phoenix-Specific TDD Practices

### LiveView TDD Approach

**Write LiveView tests first**, then implement:

1. **Test the render** - What should the user see?
2. **Test user interactions** - What happens when they click/submit?
3. **Test state management** - How does the UI state change?

**Best Practices:**

- Treat LiveViews as interface adapters in the presentation layer
- LiveViews should delegate to contexts/use cases for business logic
- Keep LiveView callbacks focused on UI state management
- Use assigns for view state, not business state
- Handle events by calling context functions and updating UI accordingly

### Channel TDD Approach

**Write Channel tests first**, then implement:

1. **Test join logic** - Can user join the channel?
2. **Test message handling** - What happens with incoming messages?
3. **Test broadcasts** - What gets sent to other clients?

**Best Practices:**

- Treat channels as interface adapters for WebSocket communication
- Channels should delegate to contexts/use cases for business operations
- Keep join/handle_in callbacks focused on message handling
- Use socket assigns for connection state
- Broadcast events after successful business operations

## When NOT to Write Tests First

In rare cases, exploratory coding is acceptable:

- **Prototyping**: Quick proof-of-concept or spike solutions
- **Learning**: Experimenting with a new library or API
- **Throwaway code**: Code that will definitely be deleted

**Important**: Once you decide to keep the code, delete it and rewrite it with TDD.

## Benefits of TDD

When following TDD, you gain:

1. **Better Designed Code**: Writing tests first forces you to think about the API and design
2. **Complete Test Coverage**: Every piece of code has a test because tests come first
3. **Living Documentation**: Tests serve as executable documentation of how code should behave
4. **Confidence in Refactoring**: Comprehensive test suite catches regressions immediately
5. **Fewer Bugs in Production**: Issues are caught early in the development cycle
6. **Faster Development**: While it seems slower initially, it prevents debugging time later

## Summary

Test-Driven Development is not optional in this project - it's the standard approach:

1. ✅ **RED**: Write a failing test first
2. ✅ **GREEN**: Write minimal code to pass the test
3. ✅ **REFACTOR**: Improve code while keeping tests green

Always write tests before implementation. Start with domain tests, work through use cases, infrastructure, and finally the interface layer. Keep tests fast, readable, and focused on behavior rather than implementation.
