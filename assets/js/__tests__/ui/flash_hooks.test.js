import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { AutoHideFlash } from '../../ui/flash_hooks'

describe('AutoHideFlash Hook', () => {
  let hook
  let mockElement

  beforeEach(() => {
    // Create mock DOM element
    mockElement = document.createElement('div')
    mockElement.click = vi.fn()

    // Create a fresh hook instance
    hook = Object.create(AutoHideFlash)
    hook.el = mockElement

    // Mock setTimeout and clearTimeout
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  describe('mounted', () => {
    it('should set timeout to auto-hide after 1 second', () => {
      hook.mounted()

      expect(hook.timeout).toBeDefined()
    })

    it('should click element after 1 second', () => {
      hook.mounted()

      // Fast-forward time by 1000ms
      vi.advanceTimersByTime(1000)

      expect(mockElement.click).toHaveBeenCalled()
    })

    it('should not click element before timeout', () => {
      hook.mounted()

      // Fast-forward time by 500ms (not enough)
      vi.advanceTimersByTime(500)

      expect(mockElement.click).not.toHaveBeenCalled()
    })
  })

  describe('destroyed', () => {
    it('should clear timeout on destroy', () => {
      const clearTimeoutSpy = vi.spyOn(global, 'clearTimeout')

      hook.mounted()
      const timeoutId = hook.timeout

      hook.destroyed()

      expect(clearTimeoutSpy).toHaveBeenCalledWith(timeoutId)
    })

    it('should not throw if no timeout set', () => {
      expect(() => {
        hook.destroyed()
      }).not.toThrow()
    })

    it('should prevent auto-click after destroy', () => {
      hook.mounted()
      hook.destroyed()

      // Fast-forward time by 1000ms
      vi.advanceTimersByTime(1000)

      // Should not click after destroy
      expect(mockElement.click).not.toHaveBeenCalled()
    })
  })
})
