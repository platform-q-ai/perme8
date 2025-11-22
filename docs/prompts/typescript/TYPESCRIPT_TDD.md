# Frontend Test-Driven Development (TDD)

**This project follows a strict Test-Driven Development approach for frontend code.**

## Overview

Test-Driven Development (TDD) for frontend ensures that TypeScript/JavaScript code, Phoenix hooks, and UI components are well-tested, maintainable, and reliable. By writing tests first, we create better-designed, more modular code with complete test coverage.

## Technology Stack

- **Vitest**: Fast unit test framework with native ESM support
- **TypeScript**: Type-safe JavaScript with compile-time checking
- **Phoenix LiveView Testing**: Server-side testing of LiveView interactions
- **DOM Testing**: Client-side DOM manipulation and event handling tests

---

## The TDD Cycle: Red-Green-Refactor

Follow this cycle for all frontend code:

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

---

## Frontend TDD Best Practices

### Always Write Tests First

- **Before writing any production code**, write the test
- Resist the temptation to write code first and test later
- Tests written first are better designed and more focused
- Start with the domain layer (pure business logic)

### Start with the Simplest Test

- Begin with the easiest case (happy path)
- Add edge cases and error cases incrementally
- Build complexity gradually
- Test one behavior at a time

### Test Behavior, Not Implementation

- Focus on **what** the code should do, not **how**
- Tests should not break when refactoring internal implementation
- Test the public API, not private functions
- Mock external dependencies

### Keep Tests Fast

- Domain tests should run in milliseconds (no I/O, no DOM)
- Use Vitest's fast execution model
- Mock external dependencies (APIs, storage, timers)
- Reserve integration tests for critical paths only

### Make Tests Readable

- Use descriptive test names that explain the scenario
- Follow Arrange-Act-Assert pattern
- One assertion per test when possible
- Use setup blocks to reduce duplication

---

## Frontend Testing Strategy

### Test Pyramid

Follow the test pyramid - more tests at the bottom, fewer at the top:

```
        /\
       /  \      Few: E2E/Integration Tests (LiveView)
      /----\
     /      \    More: Hook/Component Tests
    /--------\
   /          \  Most: Domain/Use Case Tests (Fast, Pure)
  /------------\
```

### Testing by Layer (TDD Order)

#### 1. Domain Layer (Start Here)

**Pure business logic with no dependencies on DOM, Phoenix, or external libraries.**

- Write tests first using Vitest
- No DOM, no external dependencies, no side effects
- Pure logic testing - fastest tests
- Tests should run in milliseconds
- Test edge cases and business rules thoroughly

**Example:**
```typescript
// domain/entities/shopping-cart.test.ts
import { describe, test, expect } from 'vitest'
import { ShoppingCart } from './shopping-cart'

describe('ShoppingCart', () => {
  describe('addItem', () => {
    test('adds item to empty cart', () => {
      const cart = new ShoppingCart([])
      const item = { id: '1', name: 'Product', price: 10, quantity: 1 }

      const updatedCart = cart.addItem(item)

      expect(updatedCart.items).toHaveLength(1)
      expect(updatedCart.items[0]).toEqual(item)
    })

    test('returns new cart instance (immutability)', () => {
      const cart = new ShoppingCart([])
      const item = { id: '1', name: 'Product', price: 10, quantity: 1 }

      const updatedCart = cart.addItem(item)

      expect(updatedCart).not.toBe(cart)
      expect(cart.items).toHaveLength(0)
    })
  })

  describe('calculateTotal', () => {
    test('calculates total for single item', () => {
      const items = [{ id: '1', name: 'Product', price: 10, quantity: 2 }]
      const cart = new ShoppingCart(items)

      expect(cart.calculateTotal()).toBe(20)
    })

    test('applies discount to total', () => {
      const items = [{ id: '1', name: 'Product', price: 100, quantity: 1 }]
      const cart = new ShoppingCart(items, 0.1) // 10% discount

      expect(cart.calculateTotal()).toBe(90)
    })

    test('returns zero for empty cart', () => {
      const cart = new ShoppingCart([])

      expect(cart.calculateTotal()).toBe(0)
    })
  })

  describe('canCheckout', () => {
    test('returns true when cart has items with positive total', () => {
      const items = [{ id: '1', name: 'Product', price: 10, quantity: 1 }]
      const cart = new ShoppingCart(items)

      expect(cart.canCheckout()).toBe(true)
    })

    test('returns false when cart is empty', () => {
      const cart = new ShoppingCart([])

      expect(cart.canCheckout()).toBe(false)
    })

    test('returns false when total is zero', () => {
      const items = [{ id: '1', name: 'Product', price: 0, quantity: 1 }]
      const cart = new ShoppingCart(items)

      expect(cart.canCheckout()).toBe(false)
    })
  })
})
```

**Implementation:**
```typescript
// domain/entities/shopping-cart.ts
export interface CartItem {
  id: string
  name: string
  price: number
  quantity: number
}

export class ShoppingCart {
  constructor(
    public readonly items: CartItem[],
    public readonly discount: number = 0
  ) {}

  addItem(item: CartItem): ShoppingCart {
    return new ShoppingCart([...this.items, item], this.discount)
  }

  calculateTotal(): number {
    const subtotal = this.items.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0
    )
    return subtotal * (1 - this.discount)
  }

  canCheckout(): boolean {
    return this.items.length > 0 && this.calculateTotal() > 0
  }
}
```

#### 2. Application Layer (Use Cases)

**Orchestrates business logic and handles side effects.**

- Write tests first using Vitest
- Mock infrastructure dependencies (API, storage)
- Test orchestration and workflows
- Test async operations and error handling

**Example:**
```typescript
// application/use-cases/add-to-cart.test.ts
import { describe, test, expect, vi, beforeEach } from 'vitest'
import { AddToCart } from './add-to-cart'
import type { CartRepository } from '../../infrastructure/storage/cart-repository'
import type { PriceService } from '../../infrastructure/api/price-service'
import { ShoppingCart } from '../../domain/entities/shopping-cart'

describe('AddToCart', () => {
  let mockRepository: CartRepository
  let mockPriceService: PriceService
  let useCase: AddToCart

  beforeEach(() => {
    mockRepository = {
      load: vi.fn(),
      save: vi.fn()
    }
    mockPriceService = {
      getPrice: vi.fn()
    }
    useCase = new AddToCart(mockRepository, mockPriceService)
  })

  test('adds item to existing cart', async () => {
    const existingCart = new ShoppingCart([
      { id: '1', name: 'Product 1', price: 10, quantity: 1 }
    ])
    vi.mocked(mockRepository.load).mockResolvedValue(existingCart)
    vi.mocked(mockPriceService.getPrice).mockResolvedValue(20)

    await useCase.execute('2', 2)

    expect(mockRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        items: expect.arrayContaining([
          expect.objectContaining({ id: '1' }),
          expect.objectContaining({ id: '2', quantity: 2, price: 20 })
        ])
      })
    )
  })

  test('creates new cart when none exists', async () => {
    vi.mocked(mockRepository.load).mockResolvedValue(new ShoppingCart([]))
    vi.mocked(mockPriceService.getPrice).mockResolvedValue(15)

    await useCase.execute('1', 1)

    expect(mockRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        items: [expect.objectContaining({ id: '1', price: 15 })]
      })
    )
  })

  test('throws error when price service fails', async () => {
    vi.mocked(mockRepository.load).mockResolvedValue(new ShoppingCart([]))
    vi.mocked(mockPriceService.getPrice).mockRejectedValue(
      new Error('Price not found')
    )

    await expect(useCase.execute('1', 1)).rejects.toThrow('Price not found')
    expect(mockRepository.save).not.toHaveBeenCalled()
  })

  test('handles repository save failure', async () => {
    vi.mocked(mockRepository.load).mockResolvedValue(new ShoppingCart([]))
    vi.mocked(mockPriceService.getPrice).mockResolvedValue(10)
    vi.mocked(mockRepository.save).mockRejectedValue(
      new Error('Storage full')
    )

    await expect(useCase.execute('1', 1)).rejects.toThrow('Storage full')
  })
})
```

**Implementation:**
```typescript
// application/use-cases/add-to-cart.ts
import { ShoppingCart } from '../../domain/entities/shopping-cart'
import type { CartRepository } from '../../infrastructure/storage/cart-repository'
import type { PriceService } from '../../infrastructure/api/price-service'

export class AddToCart {
  constructor(
    private repository: CartRepository,
    private priceService: PriceService
  ) {}

  async execute(productId: string, quantity: number): Promise<void> {
    const cart = await this.repository.load()
    const price = await this.priceService.getPrice(productId)

    const item = {
      id: productId,
      name: `Product ${productId}`, // Would come from product service
      price,
      quantity
    }

    const updatedCart = cart.addItem(item)
    await this.repository.save(updatedCart)
  }
}
```

#### 3. Infrastructure Layer

**Handles external dependencies like APIs, storage, and browser APIs.**

- Write tests first using Vitest
- Mock browser APIs (localStorage, fetch, etc.)
- Test adapters and integration points
- Test error handling and edge cases

**Example:**
```typescript
// infrastructure/storage/local-storage-cart-repository.test.ts
import { describe, test, expect, beforeEach, vi } from 'vitest'
import { LocalStorageCartRepository } from './local-storage-cart-repository'
import { ShoppingCart } from '../../domain/entities/shopping-cart'

describe('LocalStorageCartRepository', () => {
  let repository: LocalStorageCartRepository
  let mockStorage: Record<string, string>

  beforeEach(() => {
    mockStorage = {}

    // Mock localStorage
    global.localStorage = {
      getItem: vi.fn((key: string) => mockStorage[key] ?? null),
      setItem: vi.fn((key: string, value: string) => {
        mockStorage[key] = value
      }),
      removeItem: vi.fn((key: string) => {
        delete mockStorage[key]
      }),
      clear: vi.fn(() => {
        mockStorage = {}
      }),
      length: 0,
      key: vi.fn()
    }

    repository = new LocalStorageCartRepository()
  })

  describe('load', () => {
    test('loads cart from localStorage', async () => {
      const cartData = {
        items: [{ id: '1', name: 'Product', price: 10, quantity: 1 }],
        discount: 0.1
      }
      mockStorage['shopping-cart'] = JSON.stringify(cartData)

      const cart = await repository.load()

      expect(cart.items).toHaveLength(1)
      expect(cart.items[0].id).toBe('1')
      expect(cart.discount).toBe(0.1)
    })

    test('returns empty cart when no data exists', async () => {
      const cart = await repository.load()

      expect(cart.items).toHaveLength(0)
      expect(cart.discount).toBe(0)
    })

    test('returns empty cart when data is invalid', async () => {
      mockStorage['shopping-cart'] = 'invalid-json'

      const cart = await repository.load()

      expect(cart.items).toHaveLength(0)
    })
  })

  describe('save', () => {
    test('saves cart to localStorage', async () => {
      const items = [{ id: '1', name: 'Product', price: 10, quantity: 1 }]
      const cart = new ShoppingCart(items, 0.05)

      await repository.save(cart)

      const saved = JSON.parse(mockStorage['shopping-cart'])
      expect(saved.items).toHaveLength(1)
      expect(saved.items[0].id).toBe('1')
      expect(saved.discount).toBe(0.05)
    })

    test('overwrites existing cart data', async () => {
      mockStorage['shopping-cart'] = JSON.stringify({ items: [], discount: 0 })
      const items = [{ id: '2', name: 'New', price: 20, quantity: 2 }]
      const cart = new ShoppingCart(items)

      await repository.save(cart)

      const saved = JSON.parse(mockStorage['shopping-cart'])
      expect(saved.items).toHaveLength(1)
      expect(saved.items[0].id).toBe('2')
    })
  })
})
```

**Implementation:**
```typescript
// infrastructure/storage/local-storage-cart-repository.ts
import { ShoppingCart, CartItem } from '../../domain/entities/shopping-cart'

export interface CartRepository {
  load(): Promise<ShoppingCart>
  save(cart: ShoppingCart): Promise<void>
}

export class LocalStorageCartRepository implements CartRepository {
  private readonly key = 'shopping-cart'

  async load(): Promise<ShoppingCart> {
    try {
      const data = localStorage.getItem(this.key)
      if (!data) return new ShoppingCart([])

      const parsed = JSON.parse(data)
      return new ShoppingCart(parsed.items, parsed.discount)
    } catch {
      return new ShoppingCart([])
    }
  }

  async save(cart: ShoppingCart): Promise<void> {
    const data = JSON.stringify({
      items: cart.items,
      discount: cart.discount
    })
    localStorage.setItem(this.key, data)
  }
}
```

#### 4. Presentation Layer (Phoenix Hooks)

**Handles DOM interactions and LiveView integration.**

- Write tests first (for testable logic, extract to use cases)
- Test DOM manipulation and event handling
- Test LiveView event communication
- Keep hooks thin - delegate to use cases

**Example:**
```typescript
// presentation/hooks/cart-updater.test.ts
import { describe, test, expect, vi, beforeEach } from 'vitest'
import { CartUpdater } from './cart-updater'
import type { AddToCart } from '../../application/use-cases/add-to-cart'

describe('CartUpdater Hook', () => {
  let hook: CartUpdater
  let mockElement: HTMLElement
  let mockUseCase: AddToCart
  let mockPushEvent: ReturnType<typeof vi.fn>

  beforeEach(() => {
    // Create mock DOM element
    mockElement = document.createElement('button')
    mockElement.dataset.productId = '123'
    mockElement.dataset.quantity = '2'

    // Create mock use case
    mockUseCase = {
      execute: vi.fn()
    } as any

    // Create hook instance
    hook = new CartUpdater()
    hook.el = mockElement
    hook.pushEvent = mockPushEvent = vi.fn()

    // Inject mock use case (in real code, would be done via DI)
    ;(hook as any).useCase = mockUseCase
  })

  test('adds item to cart on click', async () => {
    vi.mocked(mockUseCase.execute).mockResolvedValue()

    await mockElement.click()

    expect(mockUseCase.execute).toHaveBeenCalledWith('123', 2)
  })

  test('pushes event to LiveView on success', async () => {
    vi.mocked(mockUseCase.execute).mockResolvedValue()

    await mockElement.click()
    // Wait for async operation
    await new Promise(resolve => setTimeout(resolve, 0))

    expect(mockPushEvent).toHaveBeenCalledWith('cart-updated', {
      productId: '123',
      quantity: 2
    })
  })

  test('shows success message on successful add', async () => {
    vi.mocked(mockUseCase.execute).mockResolvedValue()
    const showSuccessSpy = vi.spyOn(hook as any, 'showSuccess')

    await mockElement.click()
    await new Promise(resolve => setTimeout(resolve, 0))

    expect(showSuccessSpy).toHaveBeenCalled()
  })

  test('shows error message on failure', async () => {
    const error = new Error('Failed to add item')
    vi.mocked(mockUseCase.execute).mockRejectedValue(error)
    const showErrorSpy = vi.spyOn(hook as any, 'showError')

    await mockElement.click()
    await new Promise(resolve => setTimeout(resolve, 0))

    expect(showErrorSpy).toHaveBeenCalledWith(error)
    expect(mockPushEvent).not.toHaveBeenCalled()
  })

  test('uses default quantity of 1 when not specified', async () => {
    delete mockElement.dataset.quantity
    vi.mocked(mockUseCase.execute).mockResolvedValue()

    await mockElement.click()

    expect(mockUseCase.execute).toHaveBeenCalledWith('123', 1)
  })
})
```

**Implementation:**
```typescript
// presentation/hooks/cart-updater.ts
import { AddToCart } from '../../application/use-cases/add-to-cart'
import { LocalStorageCartRepository } from '../../infrastructure/storage/cart-repository'
import { HttpPriceService } from '../../infrastructure/api/price-service'

export class CartUpdater {
  el: HTMLElement
  pushEvent: (event: string, payload: any) => void
  private useCase: AddToCart

  mounted() {
    const repository = new LocalStorageCartRepository()
    const priceService = new HttpPriceService()
    this.useCase = new AddToCart(repository, priceService)

    this.el.addEventListener('click', this.handleAddToCart)
  }

  handleAddToCart = async (event: Event) => {
    const button = event.target as HTMLButtonElement
    const productId = button.dataset.productId!
    const quantity = parseInt(button.dataset.quantity || '1')

    try {
      await this.useCase.execute(productId, quantity)
      this.showSuccess()
      this.pushEvent('cart-updated', { productId, quantity })
    } catch (error) {
      this.showError(error as Error)
    }
  }

  showSuccess(): void {
    this.el.classList.add('success')
    setTimeout(() => this.el.classList.remove('success'), 2000)
  }

  showError(error: Error): void {
    this.el.classList.add('error')
    console.error('Failed to add to cart:', error)
    setTimeout(() => this.el.classList.remove('error'), 2000)
  }

  destroyed() {
    this.el.removeEventListener('click', this.handleAddToCart)
  }
}
```

---

## Test Organization

```
assets/
├── js/
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── shopping-cart.ts
│   │   │   └── shopping-cart.test.ts
│   │   └── policies/
│   │       ├── discount-policy.ts
│   │       └── discount-policy.test.ts
│   ├── application/
│   │   └── use-cases/
│   │       ├── add-to-cart.ts
│   │       └── add-to-cart.test.ts
│   ├── infrastructure/
│   │   ├── storage/
│   │   │   ├── cart-repository.ts
│   │   │   └── cart-repository.test.ts
│   │   └── api/
│   │       ├── price-service.ts
│   │       └── price-service.test.ts
│   └── presentation/
│       └── hooks/
│           ├── cart-updater.ts
│           └── cart-updater.test.ts
└── test/
    ├── setup.ts           # Vitest setup
    └── helpers/           # Test utilities
```

---

## Running Frontend Tests

```bash
# Run tests in watch mode (recommended during TDD)
npm run test:watch

# Run all tests
npm run test

# Run specific test file
npm run test cart-updater.test.ts

# Run tests with coverage
npm run test:coverage

# Run tests in CI mode
npm run test:ci
```

### Vitest Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./assets/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      exclude: ['node_modules/', 'assets/test/']
    }
  }
})
```

---

## Phoenix LiveView Integration Testing

Test LiveView interactions from the server side:

**Example:**
```elixir
# test/jarga_web/live/cart_live_test.exs
defmodule JargaWeb.CartLiveTest do
  use JargaWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "cart page" do
    test "displays cart items", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cart")

      assert view
             |> element("#cart-item-1")
             |> render() =~ "Product Name"
    end

    test "updates cart when item added via hook", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cart")

      # Simulate hook event
      view
      |> element("#add-to-cart-btn")
      |> render_hook("cart-updated", %{
        "productId" => "123",
        "quantity" => 2
      })

      assert render(view) =~ "2 items"
    end

    test "shows error when cart operation fails", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cart")

      view
      |> element("#checkout-btn")
      |> render_click()

      assert render(view) =~ "Unable to process checkout"
    end
  end
end
```

---

## TDD Workflow Example

### Feature Request: "Add quantity validation to shopping cart"

**Step 1: Write Domain Tests**

```typescript
// domain/entities/shopping-cart.test.ts
describe('ShoppingCart validation', () => {
  test('throws error when adding item with negative quantity', () => {
    const cart = new ShoppingCart([])
    const item = { id: '1', name: 'Product', price: 10, quantity: -1 }

    expect(() => cart.addItem(item)).toThrow('Quantity must be positive')
  })

  test('throws error when adding item with zero quantity', () => {
    const cart = new ShoppingCart([])
    const item = { id: '1', name: 'Product', price: 10, quantity: 0 }

    expect(() => cart.addItem(item)).toThrow('Quantity must be positive')
  })

  test('accepts item with positive quantity', () => {
    const cart = new ShoppingCart([])
    const item = { id: '1', name: 'Product', price: 10, quantity: 1 }

    expect(() => cart.addItem(item)).not.toThrow()
  })
})
```

**Step 2: Implement Domain Logic**

```typescript
// domain/entities/shopping-cart.ts
addItem(item: CartItem): ShoppingCart {
  if (item.quantity <= 0) {
    throw new Error('Quantity must be positive')
  }
  return new ShoppingCart([...this.items, item], this.discount)
}
```

**Step 3: Write Use Case Tests**

```typescript
// application/use-cases/add-to-cart.test.ts
test('throws validation error for invalid quantity', async () => {
  vi.mocked(mockRepository.load).mockResolvedValue(new ShoppingCart([]))
  vi.mocked(mockPriceService.getPrice).mockResolvedValue(10)

  await expect(useCase.execute('1', -1)).rejects.toThrow('Quantity must be positive')
  expect(mockRepository.save).not.toHaveBeenCalled()
})
```

**Step 4: Update Use Case (may already pass)**

**Step 5: Write Hook Tests**

```typescript
// presentation/hooks/cart-updater.test.ts
test('shows validation error for invalid quantity', async () => {
  mockElement.dataset.quantity = '-1'
  const error = new Error('Quantity must be positive')
  vi.mocked(mockUseCase.execute).mockRejectedValue(error)

  await mockElement.click()
  await new Promise(resolve => setTimeout(resolve, 0))

  expect(mockElement.classList.contains('error')).toBe(true)
})
```

**Step 6: Update Hook (may already handle errors)**

---

## Best Practices Summary

### 1. Test Organization
- Collocate tests with source files
- Use clear, descriptive test names
- Group related tests with `describe` blocks
- Use `beforeEach` for common setup

### 2. Mocking Strategy
- Mock external dependencies (APIs, storage, timers)
- Use Vitest's `vi.fn()` and `vi.mock()` for mocking
- Keep domain layer pure (no mocks needed)
- Mock at boundaries (infrastructure layer)

### 3. TypeScript in Tests
- Use strict typing in tests
- Define test fixtures with proper types
- Use type assertions sparingly (`as`)
- Leverage TypeScript for test refactoring

### 4. Async Testing
- Use `async/await` for async operations
- Don't forget to `await` promises in tests
- Test both success and error paths
- Use `vi.useFakeTimers()` for time-dependent tests

### 5. Test Maintainability
- Keep tests simple and focused
- Avoid testing implementation details
- Use helper functions for common operations
- Refactor tests along with production code

---

## Benefits of Frontend TDD

When following TDD for frontend code, you gain:

1. **Better API Design**: Writing tests first forces you to think about interfaces
2. **Type Safety**: TypeScript catches errors at compile time
3. **Modular Code**: TDD encourages small, focused, testable functions
4. **Confidence**: Comprehensive test suite catches regressions immediately
5. **Documentation**: Tests serve as executable documentation
6. **Faster Debugging**: Issues are caught early in the development cycle
7. **Easier Refactoring**: Tests provide safety net for changes

---

## Summary

Frontend TDD follows the same Red-Green-Refactor cycle as backend TDD:

1. ✅ **RED**: Write a failing test first
2. ✅ **GREEN**: Write minimal code to pass the test
3. ✅ **REFACTOR**: Improve code while keeping tests green

**Testing Order:**
1. Domain layer (pure business logic) - Start here
2. Application layer (use cases with mocked dependencies)
3. Infrastructure layer (adapters with mocked browser APIs)
4. Presentation layer (hooks with mocked use cases)

**Key Principles:**
- Keep domain logic pure and framework-agnostic
- Test behavior, not implementation
- Mock at architectural boundaries
- Keep tests fast and focused
- Use TypeScript for type safety in tests
- Follow SOLID principles in test design

By following TDD for frontend code, you create maintainable, testable, and reliable client-side applications that integrate seamlessly with Phoenix LiveView.
