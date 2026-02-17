/**
 * Tests for FlashHook (Presentation Layer)
 *
 * TDD RED Phase - Writing failing tests first
 *
 * Purpose: Flash message auto-hide behavior
 * Responsibilities:
 * - Auto-hide flash message after timeout (default 5 seconds)
 * - Fade out animation using CSS classes
 * - Remove element from DOM after fade completes
 * - Configurable timeout via data attribute
 * - Handle manual close button clicks
 */

import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest'
import { FlashHook } from '../../../presentation/hooks/flash-hook'

describe('FlashHook', () => {
  let hook: FlashHook
  let mockElement: HTMLElement

  beforeEach(() => {
    // Setup fake timers for testing setTimeout
    vi.useFakeTimers()

    // Create mock element
    mockElement = document.createElement('div')
    mockElement.classList.add('flash-message')

    // Initialize phxPrivate property required by ViewHook
    ;(mockElement as any).phxPrivate = {}

    // Create hook instance
    hook = new FlashHook(null as any, mockElement)
  })

  afterEach(() => {
    vi.restoreAllMocks()
    vi.useRealTimers()
  })

  describe('mounted', () => {
    test('sets up auto-hide timer with default timeout (5 seconds)', () => {
      hook.mounted()

      // Should not be hidden immediately
      expect(mockElement.classList.contains('fade-out')).toBe(false)

      // Fast forward 4999ms (just before timeout)
      vi.advanceTimersByTime(4999)
      expect(mockElement.classList.contains('fade-out')).toBe(false)

      // Fast forward 1ms more (exactly at 5000ms)
      vi.advanceTimersByTime(1)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })

    test('uses custom timeout from data attribute', () => {
      mockElement.dataset.timeout = '3000'

      hook.mounted()

      // Should not be hidden before custom timeout
      vi.advanceTimersByTime(2999)
      expect(mockElement.classList.contains('fade-out')).toBe(false)

      // Should be hidden at custom timeout
      vi.advanceTimersByTime(1)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })

    test('handles invalid timeout gracefully (uses default)', () => {
      mockElement.dataset.timeout = 'invalid'

      hook.mounted()

      // Should fall back to default timeout (5000ms)
      vi.advanceTimersByTime(5000)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })

    test('handles negative timeout (uses default)', () => {
      mockElement.dataset.timeout = '-100'

      hook.mounted()

      // Should fall back to default timeout (5000ms)
      vi.advanceTimersByTime(5000)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })

    test('handles zero timeout (uses default)', () => {
      mockElement.dataset.timeout = '0'

      hook.mounted()

      // Should fall back to default timeout (5000ms)
      vi.advanceTimersByTime(5000)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })

    test('removes element after fade animation completes', () => {
      const removeSpy = vi.spyOn(mockElement, 'remove')

      hook.mounted()

      // Fast forward to trigger fade-out
      vi.advanceTimersByTime(5000)
      expect(mockElement.classList.contains('fade-out')).toBe(true)

      // Fast forward additional time for fade animation (300ms)
      vi.advanceTimersByTime(300)
      expect(removeSpy).toHaveBeenCalledTimes(1)
    })
  })

  describe('manual close', () => {
    test('handles manual close button click', () => {
      const closeButton = document.createElement('button')
      closeButton.classList.add('flash-close')
      mockElement.appendChild(closeButton)

      hook.mounted()

      // Click close button
      closeButton.click()

      // Should immediately add fade-out class
      expect(mockElement.classList.contains('fade-out')).toBe(true)

      // Should remove element after animation
      const removeSpy = vi.spyOn(mockElement, 'remove')
      vi.advanceTimersByTime(300)
      expect(removeSpy).toHaveBeenCalledTimes(1)
    })

    test('cancels auto-hide timer when manually closed', () => {
      const closeButton = document.createElement('button')
      closeButton.classList.add('flash-close')
      mockElement.appendChild(closeButton)

      hook.mounted()

      // Click close button before auto-hide
      closeButton.click()

      // Fast forward past auto-hide time
      vi.advanceTimersByTime(5000)

      // Should not trigger auto-hide (already closed)
      // Element should still have fade-out (from manual close)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })

    test('handles close button that does not exist', () => {
      // No close button in element

      hook.mounted()

      // Should not throw error
      expect(() => {
        vi.advanceTimersByTime(5000)
      }).not.toThrow()
    })
  })

  describe('destroyed', () => {
    test('clears auto-hide timer', () => {
      const clearTimeoutSpy = vi.spyOn(global, 'clearTimeout')

      hook.mounted()
      hook.destroyed()

      expect(clearTimeoutSpy).toHaveBeenCalled()
    })

    test('clears auto-hide timer even if not yet triggered', () => {
      hook.mounted()

      // Fast forward only 1 second (not yet triggered - timeout is 5 seconds)
      vi.advanceTimersByTime(1000)

      hook.destroyed()

      // Fast forward past auto-hide time
      vi.advanceTimersByTime(3000)

      // Should NOT have fade-out class (timer was cleared)
      expect(mockElement.classList.contains('fade-out')).toBe(false)
    })

    test('removes close button event listener', () => {
      const closeButton = document.createElement('button')
      closeButton.classList.add('flash-close')
      mockElement.appendChild(closeButton)

      const removeEventListenerSpy = vi.spyOn(closeButton, 'removeEventListener')

      hook.mounted()
      hook.destroyed()

      expect(removeEventListenerSpy).toHaveBeenCalledWith('click', expect.any(Function))
    })

    test('handles destroyed being called before mounted', () => {
      // Should not throw error
      expect(() => {
        hook.destroyed()
      }).not.toThrow()
    })

    test('is idempotent (can be called multiple times)', () => {
      hook.mounted()

      // Should not throw error when called multiple times
      expect(() => {
        hook.destroyed()
        hook.destroyed()
        hook.destroyed()
      }).not.toThrow()
    })
  })

  describe('edge cases', () => {
    test('handles very long custom timeout', () => {
      mockElement.dataset.timeout = '60000' // 1 minute

      hook.mounted()

      vi.advanceTimersByTime(59999)
      expect(mockElement.classList.contains('fade-out')).toBe(false)

      vi.advanceTimersByTime(1)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })

    test('handles very short custom timeout', () => {
      mockElement.dataset.timeout = '100' // 100ms

      hook.mounted()

      vi.advanceTimersByTime(99)
      expect(mockElement.classList.contains('fade-out')).toBe(false)

      vi.advanceTimersByTime(1)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })

    test('handles element without any classes initially', () => {
      const plainElement = document.createElement('div')
      hook.el = plainElement

      hook.mounted()

      vi.advanceTimersByTime(5000)

      expect(plainElement.classList.contains('fade-out')).toBe(true)
    })

    test('does not interfere with existing classes', () => {
      mockElement.classList.add('custom-class')
      mockElement.classList.add('another-class')

      hook.mounted()

      vi.advanceTimersByTime(5000)

      expect(mockElement.classList.contains('custom-class')).toBe(true)
      expect(mockElement.classList.contains('another-class')).toBe(true)
      expect(mockElement.classList.contains('fade-out')).toBe(true)
    })
  })
})
