# Fullstack Design Principles

This document presents the core design principles that govern both backend (Elixir/Phoenix) and frontend (TypeScript/JavaScript) development in this project. It focuses on concepts, reasoning, and architectural patterns without code examples.

## Table of Contents

- [Core Philosophy](#core-philosophy)
- [SOLID Principles](#solid-principles)
- [Clean Architecture](#clean-architecture)
- [Testing Strategy](#testing-strategy)
- [Integration Patterns](#integration-patterns)

---

## Core Philosophy

### Test-Driven Development (TDD)

All code, both backend and frontend, follows strict Test-Driven Development:

**The Red-Green-Refactor Cycle:**
1. **Red**: Write a failing test that describes desired behavior
2. **Green**: Write minimal code to make the test pass
3. **Refactor**: Improve code quality while maintaining passing tests

**Why TDD:**
- Ensures complete test coverage from the start
- Creates better-designed, more testable code
- Provides living documentation
- Enables confident refactoring
- Catches regressions early
- Reduces bugs in production

**When to Break TDD:**
- Prototyping/proof-of-concept (must delete and rewrite with TDD if kept)
- Learning new libraries/APIs
- Throwaway code

### Architectural Boundaries

The project enforces strict architectural boundaries using the Boundary library for Elixir and layer conventions for TypeScript.

**Key Principles:**
- Core business logic never depends on frameworks or infrastructure
- Interface/presentation layers are thin adapters
- Context independence - each domain is isolated
- Communication only through public APIs
- Compile-time enforcement prevents violations

---

## SOLID Principles

### Single Responsibility Principle (SRP)

**Concept:** A module should have one, and only one, reason to change.

**Application:**
- Each module handles one specific domain concept or responsibility
- Separate business logic, data access, validation, and presentation
- Backend: Separate Ecto schemas (data) from domain logic (behavior)
- Frontend: Separate DOM manipulation from business rules
- Small, focused functions and modules

**Reasoning:**
- Easier to understand and maintain
- Changes are localized and predictable
- Reduces coupling between unrelated concerns
- Simplifies testing by isolating responsibilities

### Open/Closed Principle (OCP)

**Concept:** Software entities should be open for extension but closed for modification.

**Application:**
- Backend: Use behaviors and protocols for extensibility
- Frontend: Use TypeScript interfaces and composition
- Leverage pattern matching to add cases without modifying existing code
- Plugin patterns for adding functionality

**Reasoning:**
- New features don't require modifying existing, tested code
- Reduces risk of introducing bugs
- Enables polymorphism and flexibility
- Supports growing requirements without rewriting

### Liskov Substitution Principle (LSP)

**Concept:** Objects should be replaceable with instances of their subtypes without altering correctness.

**Application:**
- Backend: Any module implementing a behavior must be substitutable
- Frontend: Any implementation of an interface must maintain the contract
- Consistent return types across implementations
- Protocol implementations must preserve expected behavior

**Reasoning:**
- Enables reliable polymorphism
- Makes code predictable and trustworthy
- Allows swapping implementations without breaking clients
- Supports dependency injection and testing

### Interface Segregation Principle (ISP)

**Concept:** Clients should not be forced to depend on interfaces they don't use.

**Application:**
- Create small, focused behaviors with minimal required callbacks
- Backend: Context modules expose focused public APIs
- Frontend: Define role-based interfaces for specific client needs
- Avoid fat interfaces that force unnecessary dependencies

**Reasoning:**
- Reduces coupling between modules
- Makes interfaces easier to implement
- Prevents ripple effects from interface changes
- Improves code clarity and maintainability

### Dependency Inversion Principle (DIP)

**Concept:** Depend on abstractions, not concretions.

**Application:**
- Backend: Use behaviors and protocols instead of concrete modules
- Frontend: Use TypeScript interfaces instead of concrete classes
- Inject dependencies as function arguments or constructor parameters
- Configure dependencies via application config or dependency injection

**Reasoning:**
- Makes code testable through mocking
- Enables swapping implementations
- Reduces coupling to specific implementations
- Supports different configurations for different environments

---

## Clean Architecture

### The Four Layers

Clean Architecture organizes code into concentric layers with dependencies pointing inward.

#### 1. Domain Layer (Innermost)

**Purpose:** Contains pure business logic and rules.

**Characteristics:**
- No dependencies on frameworks, libraries, or infrastructure
- Backend: Pure Elixir modules with domain entities and business rules
- Frontend: Pure TypeScript/JavaScript with no DOM or external dependencies
- Completely testable in isolation
- Immutable data structures and functional operations

**Why:**
- Business logic is protected from framework changes
- Fastest tests - no I/O, no setup
- Reusable across different interfaces
- Clear expression of business concepts

#### 2. Application Layer (Use Cases)

**Purpose:** Orchestrates domain logic and defines application-specific operations.

**Characteristics:**
- Each use case implements one business operation
- Coordinates between domain and infrastructure layers
- Defines transaction boundaries
- Manages side effects (async operations, API calls)
- Returns consistent result tuples

**Why:**
- Centralizes business workflows
- Clear entry points for features
- Testable with mocked dependencies
- Separates orchestration from implementation

#### 3. Infrastructure Layer

**Purpose:** Handles technical implementation details.

**Characteristics:**
- Backend: Ecto schemas, repos, queries, external API clients
- Frontend: HTTP clients, browser storage, event emitters
- Depends on domain layer (adapts domain to external world)
- Implements interfaces defined by application needs

**Why:**
- Isolates technical complexity
- Enables swapping data sources or external services
- Protects domain from infrastructure changes
- Provides clear boundaries for integration testing

#### 4. Interface/Presentation Layer (Outermost)

**Purpose:** Handles user interaction and external interfaces.

**Characteristics:**
- Backend: Phoenix controllers, LiveViews, channels
- Frontend: Phoenix hooks, UI components, DOM utilities
- Thin layer - only transforms data between external world and application
- No business logic
- Delegates to use cases

**Why:**
- Separates UI concerns from business logic
- Enables multiple interfaces (web, API, mobile) for same business logic
- Makes UI changes independent of business rules
- Simplifies testing of user interactions

### The Dependency Rule

**Critical Principle:** Dependencies must point inward only.

```
Interface Layer → Application Layer → Domain Layer
              ↘ Infrastructure Layer ↗
```

**Implications:**
- Domain layer has zero dependencies
- Application layer depends only on domain
- Infrastructure depends on domain (implements domain interfaces)
- Interface layer depends on application and infrastructure
- Inner layers never import outer layers

**Why:**
- Protects business logic from external changes
- Enables testing layers independently
- Makes architecture changes easier
- Prevents tight coupling

### Context Organization (Backend)

Phoenix contexts serve as application boundaries that encapsulate business domains.

**Principles:**
- Each context represents a specific business domain
- Only expose necessary functions through context module
- Hide implementation details (queries, policies, schemas)
- Contexts are independent - no direct cross-context dependencies
- Cross-context communication only through public APIs

**Reasoning:**
- Clear separation of business domains
- Prevents domain logic from leaking
- Enables teams to work independently
- Makes large codebases navigable

---

## Testing Strategy

### Test Pyramid

Follow the test pyramid - more tests at the bottom, fewer at the top:

```
        /\
       /UI\ ← Few (slow, brittle)
      /────\
     /Integ\ ← Some (moderate speed)
    /──────\
   / Unit  \ ← Many (fast, focused)
  /────────\
```

### Testing by Layer (TDD Order)

**1. Domain Layer (Start Here):**
- Pure unit tests with no external dependencies
- Backend: ExUnit.Case (no database)
- Frontend: Vitest (no DOM, no API calls)
- Test business rules and edge cases thoroughly
- Fastest tests - run in milliseconds
- Should constitute the majority of tests

**2. Application Layer (Use Cases):**
- Test orchestration and workflows
- Backend: Use DataCase with database, mock external services with Mox
- Frontend: Use Vitest with mocked infrastructure
- Test transaction boundaries
- Verify correct coordination between domain and infrastructure

**3. Infrastructure Layer:**
- Integration tests with real external services
- Backend: Test queries, repos with real database
- Frontend: Test API adapters, storage with browser APIs
- Use sandboxing for isolation
- Keep fast but thorough

**4. Interface Layer (Last):**
- Test user interactions and protocol concerns
- Backend: Test controllers, LiveViews with ConnCase
- Frontend: Test hooks with mocked DOM and LiveView
- Focus on HTTP concerns, rendering, event handling
- Mock business logic - already tested in lower layers

### Test Organization Principles

**Collocate tests with code:**
- Backend: `test/` directory mirrors `lib/` structure
- Frontend: `__tests__/` directories alongside source files

**Test behavior, not implementation:**
- Focus on what code should do, not how
- Tests shouldn't break when refactoring internals
- Test public APIs, not private functions

**Keep tests fast:**
- Domain tests run in milliseconds
- Use mocks/stubs for external dependencies
- Reserve slow integration tests for critical paths
- Fast tests encourage frequent running

**Make tests readable:**
- Descriptive names that explain the scenario
- Follow Arrange-Act-Assert pattern
- One assertion per test when possible
- Use setup blocks to reduce duplication

---

## Integration Patterns

### Backend-Frontend Communication

**Phoenix LiveView Integration:**
- LiveView handles server-side rendering and state
- Phoenix hooks provide client-side interactivity
- Use the `Perme8.Events.EventBus` for real-time updates (wraps Phoenix.PubSub)
- Hooks delegate to frontend use cases, not inline logic

**Event Flow:**
- User interaction → Hook captures event
- Hook delegates to frontend use case
- Use case applies business logic
- Hook updates DOM and/or pushes event to LiveView
- LiveView processes event with backend use case
- Use case emits structured domain event via `EventBus.emit(%SomeEvent{...})`
- EventBus broadcasts to topic-derived subscribers (e.g., `events:workspace:{id}`)
- All connected LiveViews receive the event struct in `handle_info/2` and update UI

### Critical: Domain Events and Transactions

**Rule:** Always emit domain events AFTER transactions commit.

**Reasoning:**
- Emitting inside a transaction creates race conditions
- Listeners may query database before transaction commits
- They would see stale data
- Can cause data inconsistencies

**Pattern:**
1. Complete database transaction
2. Pattern match on success result
3. Emit domain event via `event_bus.emit(%Event{...})` after commit confirmed
4. Handle result appropriately

**Implementation:** Use cases inject `event_bus` via `opts[:event_bus]` and emit typed `DomainEvent` structs. Never call `Phoenix.PubSub.broadcast` directly from use cases.

### Separation of Ecto Schemas and Domain Logic

**Backend Pattern:**
- Ecto schemas live in infrastructure layer (data persistence)
- Domain entities are separate modules (business behavior)
- Repositories convert between schemas and entities
- Changesets only validate data, not business rules

**Reasoning:**
- Domain logic doesn't depend on Ecto
- Business rules are database-agnostic
- Easier to test domain without database
- Can swap data stores without changing domain

### Dependency Injection Across Stack

**Backend:**
- Use application config for compile-time configuration
- Pass dependencies as function arguments (keyword lists)
- Provide defaults while allowing test overrides
- Use behaviors to define contracts

**Frontend:**
- Pass dependencies as constructor arguments
- Provide defaults in production code
- Inject mocks in tests
- Use interfaces to define contracts

**Reasoning:**
- Makes code testable
- Enables different configurations per environment
- Reduces coupling to concrete implementations
- Supports development, test, and production needs

### Query Objects Pattern

**Concept:** Extract complex queries into dedicated, composable modules.

**Backend:**
- Query modules return Ecto queryables, not results
- Compose queries from small, reusable functions
- Keep repositories thin

**Frontend:**
- Extract complex data transformations
- Make operations composable
- Separate query logic from presentation

**Reasoning:**
- Queries are reusable across contexts
- Easier to test in isolation
- Reduces repository/service complexity
- Makes queries composable and maintainable

### Use Cases as Application Boundaries

**Pattern:** Each significant business operation is a use case.

**Characteristics:**
- One use case per business operation
- Encapsulates a complete workflow
- Defines transaction boundaries
- Returns consistent result types
- Accepts dependencies for testing

**Reasoning:**
- Clear entry points for features
- Centralizes complex workflows
- Testable in isolation
- Documents business operations
- Enables reuse across different interfaces

---

## Summary

### Unified Principles

**Architecture:**
- Clean Architecture with four distinct layers
- Dependency rule: dependencies point inward
- Domain-driven design with bounded contexts
- Framework independence at the core

**Code Quality:**
- SOLID principles guide all design decisions
- Test-Driven Development ensures quality
- Dependency injection enables testing
- Immutable data patterns for predictability

**Testing:**
- Test pyramid: many unit tests, fewer integration tests
- Test behavior, not implementation
- Write tests first (Red-Green-Refactor)
- Fast tests enable rapid feedback

**Integration:**
- Clear boundaries between backend and frontend
- Thin presentation layers
- Business logic in domain and application layers
- Infrastructure isolated from business concerns

### Benefits

Following these principles provides:

1. **Maintainability**: Clear organization makes code easy to understand and modify
2. **Testability**: Every component can be tested in isolation
3. **Flexibility**: Easy to swap implementations and adapt to changes
4. **Scalability**: Clear boundaries allow teams to work independently
5. **Reliability**: TDD and strong typing catch errors early
6. **Performance**: Clean separation enables targeted optimization
7. **Longevity**: Framework-independent core protects against technology changes

### The Path Forward

When implementing new features:

1. Start with domain tests and logic (innermost layer)
2. Add application layer tests and use cases
3. Implement infrastructure adapters
4. Finally, add interface/presentation layer
5. Always follow Red-Green-Refactor
6. Respect architectural boundaries
7. Keep business logic pure and framework-free

This disciplined approach ensures a robust, maintainable, and scalable fullstack application that can evolve with changing requirements while maintaining high code quality.
