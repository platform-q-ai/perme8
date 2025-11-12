/**
 * Tests for ChatMessagesHook (Presentation Layer)
 *
 * Tests Phoenix hook for chat messages container auto-scroll behavior.
 * Extremely simple hook - only tests scroll-to-bottom functionality.
 */

import { describe, test, expect, beforeEach } from 'vitest'
import { ChatMessagesHook } from '../../../presentation/hooks/chat-messages-hook'

describe('ChatMessagesHook', () => {
  let hook: ChatMessagesHook
  let mockContainer: HTMLDivElement

  beforeEach(() => {
    // Create mock container element
    mockContainer = document.createElement('div')
    mockContainer.id = 'chat-messages'

    // Mock scrollHeight and scrollTop (readonly in real DOM)
    Object.defineProperty(mockContainer, 'scrollHeight', {
      writable: true,
      configurable: true,
      value: 1000
    })

    Object.defineProperty(mockContainer, 'scrollTop', {
      writable: true,
      configurable: true,
      value: 0
    })

    // Initialize phxPrivate property required by ViewHook
    ;(mockContainer as any).phxPrivate = {}

    // Create hook instance
    hook = new ChatMessagesHook(null as any, mockContainer)
  })

  describe('mounted', () => {
    test('scrolls to bottom on mount', () => {
      hook.mounted()

      expect(mockContainer.scrollTop).toBe(1000)
    })

    test('handles zero scrollHeight', () => {
      Object.defineProperty(mockContainer, 'scrollHeight', {
        writable: true,
        configurable: true,
        value: 0
      })

      expect(() => hook.mounted()).not.toThrow()
      expect(mockContainer.scrollTop).toBe(0)
    })
  })

  describe('updated', () => {
    test('scrolls to bottom on update', () => {
      hook.updated()

      expect(mockContainer.scrollTop).toBe(1000)
    })

    test('scrolls to new height when messages added', () => {
      hook.mounted()
      expect(mockContainer.scrollTop).toBe(1000)

      // Simulate new messages increasing scroll height
      Object.defineProperty(mockContainer, 'scrollHeight', {
        writable: true,
        configurable: true,
        value: 1500
      })

      hook.updated()

      expect(mockContainer.scrollTop).toBe(1500)
    })

    test('handles rapid updates', () => {
      hook.mounted()

      // Simulate multiple rapid updates
      for (let i = 1; i <= 5; i++) {
        Object.defineProperty(mockContainer, 'scrollHeight', {
          writable: true,
          configurable: true,
          value: 1000 + i * 100
        })

        hook.updated()
        expect(mockContainer.scrollTop).toBe(1000 + i * 100)
      }
    })
  })

  describe('edge cases', () => {
    test('handles very large scrollHeight', () => {
      Object.defineProperty(mockContainer, 'scrollHeight', {
        writable: true,
        configurable: true,
        value: 999999
      })

      hook.mounted()

      expect(mockContainer.scrollTop).toBe(999999)
    })

    test('does not throw on missing scrollHeight', () => {
      // Remove scrollHeight property
      Object.defineProperty(mockContainer, 'scrollHeight', {
        writable: true,
        configurable: true,
        value: undefined
      })

      // Should not throw, just set to undefined (which browser handles)
      expect(() => hook.mounted()).not.toThrow()
    })
  })
})
