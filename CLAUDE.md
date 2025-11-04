# CLAUDE.md

This file provides guidance to Claude Code when working with Elixir and Phoenix code in this repository.

## Architecture

**This project enforces architectural boundaries using the [Boundary](https://hexdocs.pm/boundary) library.**

📖 **See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for complete architectural documentation.**

Key architectural principles:
- **Core vs Interface Separation**: Web layer (JargaWeb) cannot be accessed by contexts
- **Context Independence**: Each context (Accounts, Workspaces, Projects) is an independent boundary
- **Public APIs Only**: Cross-context communication only through exported functions
- **Compile-Time Enforcement**: Boundary violations are caught during compilation

When adding or modifying code:
1. Respect boundary constraints defined with `use Boundary`
2. Never access internal modules (Queries, Policies) from other boundaries
3. Use context public APIs for cross-context communication
4. Verify with `mix compile` - no "forbidden reference" warnings

## Development Approach

**This project follows Test-Driven Development (TDD).**

When implementing new features or making changes:

1. **Write tests first** before writing implementation code
2. Follow the Red-Green-Refactor cycle
3. Write the minimum code needed to make tests pass
4. Refactor with confidence knowing tests will catch regressions

## Core Principles

### SOLID Principles in Elixir/Phoenix

#### Single Responsibility Principle (SRP)

- **Modules should have one reason to change**: Each module should handle one specific domain concept or responsibility
- **Separate concerns**: Keep business logic, data access, validation, and presentation separate

#### Open/Closed Principle (OCP)

- **Use behaviors and protocols**: Design for extension through protocols and behaviors rather than modification
- **Pattern matching for extensibility**: Leverage Elixir's pattern matching to add new cases without modifying existing code

#### Liskov Substitution Principle (LSP)

- **Behaviors must be reliable**: Any module implementing a behavior should be substitutable without breaking functionality
- **Protocol implementations**: Ensure protocol implementations maintain expected contracts
- **Consistent return types**: Functions implementing the same behavior should return consistent data structures

#### Interface Segregation Principle (ISP)

- **Small, focused behaviors**: Create small behaviors with minimal required callbacks
- **Context-specific APIs**: Design context modules with focused public APIs

#### Dependency Inversion Principle (DIP)

- **Depend on abstractions**: Use behaviors and protocols instead of concrete implementations
- **Inject dependencies**: Pass dependencies as function arguments or use application config

## Clean Architecture for Phoenix

### Layer Structure

```
lib/
├── my_app/               # Core Domain Layer (Business Logic)
│   ├── domain/           # Domain entities and business rules
│   │   ├── entities/     # Pure business objects
│   │   ├── value_objects/ # Immutable value types
│   │   └── policies/     # Business rules and policies
│   ├── application/      # Application Use Cases
│   │   └── use_cases/    # Application-specific business rules
│   └── infrastructure/   # Infrastructure Layer
│       ├── persistence/  # Database repos and queries
│       ├── external/     # External API clients
│       └── messaging/    # Message queues, pub/sub
├── my_app_web/           # Interface Adapters (Presentation)
│   ├── controllers/      # HTTP request handlers
│   ├── views/            # Response rendering
│   ├── live/             # LiveView modules
│   ├── components/       # Reusable UI components
│   └── channels/         # WebSocket channels
└── my_app.ex             # Application boundary
```

### Architecture Guidelines

#### 1. Domain Layer (Core Business Logic)

- **Pure business logic**: No dependencies on Phoenix, Ecto, or external frameworks
- **Domain entities**: Represent core business concepts
- **Value objects**: Immutable types representing domain values

#### 2. Application Layer (Use Cases)

- **Orchestrates domain logic**: Coordinates domain entities and infrastructure
- **Transaction boundaries**: Defines where database transactions occur

#### 3. Infrastructure Layer

- **Data persistence**: Ecto schemas, repos, and queries
- **External integrations**: API clients, message queues
- **Keep separate from domain**: Infrastructure should depend on domain, not vice versa

#### 4. Interface Layer (Phoenix Web)

- **Thin controllers**: Controllers only handle HTTP concerns (parsing, validation, rendering)
- **Delegate to use cases**: Business logic lives in application layer

### Context Organization

#### Phoenix Contexts as Application Boundaries

- **Contexts represent business domains**: Each context encapsulates a specific area of the business
- **Public API only**: Only expose necessary functions through context module

## Test-Driven Development (TDD) Workflow

### The TDD Cycle

Follow the **Red-Green-Refactor** cycle for all new code:

#### 1. Red: Write a Failing Test

- Start by writing a test that describes the desired behavior
- Run the test and confirm it fails (RED)
- The test should fail for the right reason (e.g., function doesn't exist, wrong behavior)

#### 2. Green: Make the Test Pass

- Write the minimal code needed to make the test pass
- Don't worry about perfect design at this stage
- Focus on making the test GREEN as quickly as possible

#### 3. Refactor: Improve the Code

- Clean up the code while keeping tests green
- Apply SOLID principles and design patterns
- Remove duplication and improve naming
- Tests provide safety net for refactoring

### TDD Best Practices

#### Always Write Tests First

- **Before writing any production code**, write the test
- Resist the temptation to write code first and test later
- Tests written first are better designed and more focused

#### Start with the Simplest Test

- Begin with the easiest case (happy path)
- Add edge cases and error cases incrementally
- Build complexity gradually

#### One Test at a Time

- Write one test, make it pass, then write the next
- Don't write multiple failing tests at once
- Commit after each green cycle if possible

#### Test Behavior, Not Implementation

- Focus on **what** the code should do, not **how**
- Tests should not break when refactoring internal implementation
- Test the public API, not private functions

#### Keep Tests Fast

- Domain tests should run in milliseconds (no I/O)
- Use mocks/stubs for external dependencies
- Reserve integration tests for critical paths only
- Fast tests encourage running them frequently

#### Make Tests Readable

- Use descriptive test names that explain the scenario
- Follow Arrange-Act-Assert pattern
- One assertion per test when possible
- Use setup blocks to reduce duplication

### TDD Workflow Example

When asked to implement a new feature:

**Example Request:** "Add a feature to calculate shipping costs based on weight and distance"

**TDD Response:**

1. **Start with domain tests** (test/my_app/domain/shipping_calculator_test.exs):

   ```elixir
   test "calculates shipping for 5kg over 100km"
   test "calculates shipping for 1kg over 50km"
   test "returns error for negative weight"
   ```

2. **Implement domain logic** (lib/my_app/domain/shipping_calculator.ex)

3. **Add use case tests** (test/my_app/application/calculate_shipping_test.exs):

   ```elixir
   test "calculates shipping and applies user discount"
   test "returns error when user not found"
   ```

4. **Implement use case** (lib/my_app/application/calculate_shipping.ex)

5. **Add controller/LiveView tests** (test/my_app_web/live/shipping_live_test.exs):

   ```elixir
   test "displays calculated shipping cost"
   test "shows error message for invalid input"
   ```

6. **Implement UI** (lib/my_app_web/live/shipping_live.ex)

### When NOT to Write Tests First

In rare cases, exploratory coding is acceptable:

- **Prototyping**: Quick proof-of-concept or spike solutions
- **Learning**: Experimenting with a new library or API
- **Throwaway code**: Code that will definitely be deleted

**Important**: Once you decide to keep the code, delete it and rewrite it with TDD.

## Best Practices

### 1. Separation of Ecto Schemas and Domain Logic

- Keep Ecto schemas in the infrastructure layer for data persistence
- Keep domain logic in separate domain modules
- Use changesets only for data validation, not business rules
- Domain entities should not depend on Ecto

### 2. Dependency Injection Patterns

- Use application config for swappable dependencies at compile time
- Pass dependencies explicitly as function arguments for runtime flexibility
- Provide default implementations while allowing overrides for testing
- Use keyword lists for multiple optional dependencies

### 3. Use Cases Pattern

- Create a behavior for standardized use case interface
- Each use case implements a single business operation
- Use cases orchestrate domain logic and infrastructure
- Return consistent result tuples: `{:ok, result}` or `{:error, reason}`
- Accept dependencies as keyword arguments for testability

### 4. Query Objects

- Extract complex queries into dedicated query modules
- Keep repositories thin by delegating to query objects
- Make queries composable and reusable
- Organize queries by domain entity
- Query modules return Ecto queryables, not results

### 5. Testing Strategy (TDD Approach)

**Always write tests BEFORE implementation code.**

#### Test Pyramid

Follow the test pyramid - more tests at the bottom, fewer at the top:

#### Testing by Layer (TDD Order)

1. **Domain layer** (Start Here):
   - Write tests first using `ExUnit.Case`
   - No database, no external dependencies
   - Pure logic testing - fastest tests
   - Tests should run in milliseconds
   - Test edge cases and business rules thoroughly

2. **Application layer** (Use Cases):
   - Write tests first using `MyApp.DataCase`
   - Use Mox for external dependencies
   - Test orchestration and workflows
   - Mock infrastructure services
   - Test transaction boundaries

3. **Infrastructure layer**:
   - Write tests first using `MyApp.DataCase`
   - Integration tests with real database
   - Test queries, repos, and external services
   - Use database sandbox for isolation
   - Keep these tests fast but thorough

4. **Interface layer** (Last):
   - Write tests first using `MyAppWeb.ConnCase`
   - Test controllers and LiveViews
   - Test HTTP concerns (status, redirects, rendering)
   - Mock or use test doubles for business logic
   - Focus on user interactions and UI state

#### TDD Test Organization

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

#### Running Tests During TDD

- Run tests continuously: `mix test.watch`
- Run specific test: `mix test path/to/test.exs:line_number`
- Run all tests before committing: `mix test`
- Keep tests fast - entire suite should run in seconds
- Use `async: true` when tests don't share state

## Phoenix-Specific Guidelines

### LiveView Organization (TDD Approach)

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

### Channel Organization (TDD Approach)

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

## Summary

This project follows a strict **Test-Driven Development** approach:

1. ✅ **RED**: Write a failing test first
2. ✅ **GREEN**: Write minimal code to pass the test
3. ✅ **REFACTOR**: Improve code while keeping tests green

Always write tests before implementation. This ensures:

- Better designed, more testable code
- Complete test coverage
- Living documentation
- Confidence in refactoring
- Fewer bugs in production

Follow SOLID principles and Clean Architecture patterns to keep the codebase maintainable and scalable.
