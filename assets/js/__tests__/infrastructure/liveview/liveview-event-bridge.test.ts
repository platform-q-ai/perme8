/**
 * LiveViewEventBridge Tests
 *
 * Tests for the Phoenix LiveView hook context wrapper that implements LiveViewBridge interface.
 * This adapter wraps the Phoenix hook 'this' context and provides Promise-based API.
 *
 * Test Strategy:
 * - Mock the Phoenix hook context (this from hook)
 * - Test pushEvent wrapping with Promise support
 * - Test handleEvent registration
 * - Test cleanup of event handlers
 * - All tests use mocked Phoenix hook context (infrastructure layer requirement)
 * - Tests execute in <100ms (infrastructure layer requirement)
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { LiveViewEventBridge } from '../../../infrastructure/liveview/liveview-event-bridge'

describe('LiveViewEventBridge', () => {
  let mockHookContext: any
  let bridge: LiveViewEventBridge

  beforeEach(() => {
    // Mock Phoenix hook context (the 'this' object from a hook)
    mockHookContext = {
      pushEvent: vi.fn((_event: string, _payload: any, callback?: () => void) => {
        // Simulate async push completion
        if (callback) {
          setTimeout(callback, 0)
        }
      }),
      handleEvent: vi.fn()
    }

    bridge = new LiveViewEventBridge(mockHookContext)
  })

  describe('constructor', () => {
    test('creates bridge with Phoenix hook context', () => {
      expect(bridge).toBeDefined()
      expect(bridge).toBeInstanceOf(LiveViewEventBridge)
    })

    test('stores reference to hook context', () => {
      // Bridge should store the context for later use
      expect((bridge as any).hookContext).toBe(mockHookContext)
    })
  })

  describe('pushEvent', () => {
    test('wraps Phoenix pushEvent with Promise', async () => {
      const event = 'test-event'
      const payload = { data: 'test' }

      await bridge.pushEvent(event, payload)

      expect(mockHookContext.pushEvent).toHaveBeenCalledWith(
        event,
        payload,
        expect.any(Function)
      )
    })

    test('resolves Promise when pushEvent callback is called', async () => {
      const event = 'document-update'
      const payload = { id: '123', content: 'test' }

      const result = bridge.pushEvent(event, payload)

      await expect(result).resolves.toBeUndefined()
    })

    test('can be awaited multiple times', async () => {
      await bridge.pushEvent('event1', { data: '1' })
      await bridge.pushEvent('event2', { data: '2' })
      await bridge.pushEvent('event3', { data: '3' })

      expect(mockHookContext.pushEvent).toHaveBeenCalledTimes(3)
    })

    test('passes correct event name to Phoenix hook', async () => {
      const event = 'yjs_update'
      const payload = { update: 'base64data' }

      await bridge.pushEvent(event, payload)

      expect(mockHookContext.pushEvent).toHaveBeenCalledWith(
        event,
        expect.anything(),
        expect.anything()
      )
    })

    test('passes correct payload to Phoenix hook', async () => {
      const event = 'awareness_update'
      const payload = { update: 'base64data', userId: 'user-123' }

      await bridge.pushEvent(event, payload)

      expect(mockHookContext.pushEvent).toHaveBeenCalledWith(
        expect.anything(),
        payload,
        expect.anything()
      )
    })

    test('handles empty payload', async () => {
      await bridge.pushEvent('ping', {})

      expect(mockHookContext.pushEvent).toHaveBeenCalledWith(
        'ping',
        {},
        expect.any(Function)
      )
    })

    test('handles complex nested payload', async () => {
      const complexPayload = {
        user: { id: '123', name: 'Test' },
        data: { items: [1, 2, 3], metadata: { timestamp: Date.now() } }
      }

      await bridge.pushEvent('complex-event', complexPayload)

      expect(mockHookContext.pushEvent).toHaveBeenCalledWith(
        'complex-event',
        complexPayload,
        expect.any(Function)
      )
    })
  })

  describe('handleEvent', () => {
    test('registers event handler with Phoenix hook', () => {
      const event = 'remote-update'
      const callback = vi.fn()

      bridge.handleEvent(event, callback)

      expect(mockHookContext.handleEvent).toHaveBeenCalledWith(event, callback)
    })

    test('registers multiple event handlers', () => {
      const callback1 = vi.fn()
      const callback2 = vi.fn()

      bridge.handleEvent('event1', callback1)
      bridge.handleEvent('event2', callback2)

      expect(mockHookContext.handleEvent).toHaveBeenCalledTimes(2)
      expect(mockHookContext.handleEvent).toHaveBeenCalledWith('event1', callback1)
      expect(mockHookContext.handleEvent).toHaveBeenCalledWith('event2', callback2)
    })

    test('stores event handlers for cleanup', () => {
      const callback = vi.fn()

      bridge.handleEvent('test-event', callback)

      // Bridge should track registered handlers
      const handlers = (bridge as any).eventHandlers
      expect(handlers).toBeDefined()
      expect(handlers.size).toBe(1)
      expect(handlers.has('test-event')).toBe(true)
    })

    test('passes payload to callback when event is triggered', () => {
      const callback = vi.fn()
      const payload = { data: 'test' }

      // Register handler
      bridge.handleEvent('test-event', callback)

      // Get the registered callback from mock
      const registeredCallback = mockHookContext.handleEvent.mock.calls[0][1]

      // Simulate event trigger
      registeredCallback(payload)

      expect(callback).toHaveBeenCalledWith(payload)
    })

    test('handles same event registered multiple times', () => {
      const callback1 = vi.fn()
      const callback2 = vi.fn()

      bridge.handleEvent('same-event', callback1)
      bridge.handleEvent('same-event', callback2)

      // Both should be registered (last one overwrites or both are kept)
      expect(mockHookContext.handleEvent).toHaveBeenCalledTimes(2)
    })
  })

  describe('cleanup', () => {
    test('removes all registered event handlers', () => {
      // Mock removeHandleEvent method if Phoenix provides it
      mockHookContext.removeHandleEvent = vi.fn()

      const callback1 = vi.fn()
      const callback2 = vi.fn()

      bridge.handleEvent('event1', callback1)
      bridge.handleEvent('event2', callback2)

      bridge.cleanup()

      // Check that handlers were removed (implementation may vary)
      const handlers = (bridge as any).eventHandlers
      expect(handlers.size).toBe(0)
    })

    test('can be called multiple times without error', () => {
      const callback = vi.fn()
      bridge.handleEvent('test-event', callback)

      bridge.cleanup()
      bridge.cleanup()
      bridge.cleanup()

      // Should not throw error
      const handlers = (bridge as any).eventHandlers
      expect(handlers.size).toBe(0)
    })

    test('cleanup is idempotent', () => {
      const callback = vi.fn()
      bridge.handleEvent('event', callback)

      bridge.cleanup()
      const handlersAfterFirstCleanup = (bridge as any).eventHandlers.size

      bridge.cleanup()
      const handlersAfterSecondCleanup = (bridge as any).eventHandlers.size

      expect(handlersAfterFirstCleanup).toBe(0)
      expect(handlersAfterSecondCleanup).toBe(0)
    })

    test('cleanup when no handlers registered', () => {
      // Should not throw error
      expect(() => bridge.cleanup()).not.toThrow()

      const handlers = (bridge as any).eventHandlers
      expect(handlers.size).toBe(0)
    })
  })

  describe('integration', () => {
    test('can push events and handle events together', async () => {
      const receivedCallback = vi.fn()

      // Register handler
      bridge.handleEvent('response', receivedCallback)

      // Push event
      await bridge.pushEvent('request', { data: 'test' })

      // Simulate server response
      const registeredCallback = mockHookContext.handleEvent.mock.calls[0][1]
      registeredCallback({ result: 'success' })

      expect(receivedCallback).toHaveBeenCalledWith({ result: 'success' })
      expect(mockHookContext.pushEvent).toHaveBeenCalledWith(
        'request',
        { data: 'test' },
        expect.any(Function)
      )
    })

    test('cleanup after push and handle operations', async () => {
      await bridge.pushEvent('event1', { data: '1' })
      bridge.handleEvent('event2', vi.fn())

      bridge.cleanup()

      const handlers = (bridge as any).eventHandlers
      expect(handlers.size).toBe(0)
    })
  })
})
