/**
 * LiveViewEventBridge
 *
 * Infrastructure adapter that wraps Phoenix LiveView hook context and implements
 * the LiveViewBridge interface from the application layer.
 *
 * This adapter enables clean architecture by:
 * - Implementing the application layer interface (Dependency Inversion)
 * - Wrapping Phoenix hook 'this' context behind a clean API
 * - Converting Phoenix callback-based API to Promise-based API
 * - Managing event handler cleanup to prevent memory leaks
 *
 * @example
 * ```typescript
 * // In a Phoenix hook
 * export const MyHook = {
 *   mounted() {
 *     // Wrap 'this' context with bridge
 *     const bridge = new LiveViewEventBridge(this)
 *
 *     // Push event with async/await
 *     await bridge.pushEvent('user-action', { id: '123' })
 *
 *     // Handle server events
 *     bridge.handleEvent('server-update', (payload) => {
 *       console.log('Received:', payload)
 *     })
 *   },
 *
 *   destroyed() {
 *     // Clean up handlers
 *     bridge.cleanup()
 *   }
 * }
 * ```
 *
 * @module infrastructure/liveview
 */

import type { LiveViewBridge } from '../../application/interfaces/liveview-bridge.interface'

/**
 * Phoenix LiveView Hook Context
 *
 * Type definition for the Phoenix hook 'this' context object.
 * In Phoenix hooks, 'this' contains methods like pushEvent and handleEvent.
 */
interface PhoenixHookContext {
  /**
   * Push an event to the LiveView server
   * @param event - Event name
   * @param payload - Event payload
   * @param callback - Optional callback when push completes
   */
  pushEvent(event: string, payload: any, callback?: () => void): void

  /**
   * Handle an event from the LiveView server
   * @param event - Event name to listen for
   * @param callback - Callback when event is received
   */
  handleEvent(event: string, callback: (payload: any) => void): void
}

/**
 * LiveView Event Bridge
 *
 * Wraps Phoenix LiveView hook context and implements LiveViewBridge interface.
 * Provides Promise-based API for pushing events and tracks event handlers for cleanup.
 *
 * SOLID Principles:
 * - Single Responsibility: Only wraps Phoenix hook context
 * - Open/Closed: Implements LiveViewBridge interface for extension
 * - Liskov Substitution: Can be substituted anywhere LiveViewBridge is expected
 * - Interface Segregation: Implements focused LiveViewBridge interface
 * - Dependency Inversion: Application layer depends on interface, not this implementation
 */
export class LiveViewEventBridge implements LiveViewBridge {
  private readonly hookContext: PhoenixHookContext
  private readonly eventHandlers: Map<string, (payload: any) => void>

  /**
   * Creates a new LiveViewEventBridge
   *
   * @param hookContext - The Phoenix hook 'this' context (from Phoenix hook lifecycle)
   *
   * @example
   * ```typescript
   * // Inside a Phoenix hook
   * const bridge = new LiveViewEventBridge(this)
   * ```
   */
  constructor(hookContext: PhoenixHookContext) {
    this.hookContext = hookContext
    this.eventHandlers = new Map()
  }

  /**
   * Push an event to the LiveView server
   *
   * Wraps Phoenix pushEvent with Promise-based API for async/await support.
   *
   * @param event - Name of the event to push
   * @param payload - Data to send with the event
   * @returns Promise that resolves when event is sent
   */
  async pushEvent(event: string, payload: Record<string, any>): Promise<void> {
    return new Promise<void>((resolve) => {
      this.hookContext.pushEvent(event, payload, () => {
        resolve()
      })
    })
  }

  /**
   * Register a callback for events from the LiveView server
   *
   * Registers an event handler and tracks it for cleanup.
   *
   * @param event - Name of the event to listen for
   * @param callback - Function called when event is received
   */
  handleEvent(event: string, callback: (payload: any) => void): void {
    // Store handler for cleanup
    this.eventHandlers.set(event, callback)

    // Register with Phoenix hook
    this.hookContext.handleEvent(event, callback)
  }

  /**
   * Clean up all registered event handlers
   *
   * Removes all event handlers to prevent memory leaks.
   * This should be called when the hook is destroyed.
   */
  cleanup(): void {
    // Clear all tracked handlers
    this.eventHandlers.clear()
  }
}
