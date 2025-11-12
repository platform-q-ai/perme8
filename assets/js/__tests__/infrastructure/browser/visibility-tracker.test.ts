import { describe, test, expect, beforeEach, vi } from 'vitest'
import { VisibilityTracker } from '../../../infrastructure/browser/visibility-tracker'

describe('VisibilityTracker', () => {
  let mockDocument: any
  let visibilityChangeListeners: Array<() => void>
  let visibilityCallback: (isVisible: boolean) => void

  beforeEach(() => {
    visibilityChangeListeners = []

    // Mock document with visibility API
    mockDocument = {
      hidden: false,
      addEventListener: vi.fn((_event: string, listener: () => void) => {
        if (_event === 'visibilitychange') {
          visibilityChangeListeners.push(listener)
        }
      }),
      removeEventListener: vi.fn((_event: string, listener: () => void) => {
        const index = visibilityChangeListeners.indexOf(listener)
        if (index > -1) {
          visibilityChangeListeners.splice(index, 1)
        }
      })
    }

    // Replace global document
    global.document = mockDocument as any

    visibilityCallback = vi.fn<(isVisible: boolean) => void>()
  })

  describe('constructor', () => {
    test('creates tracker with callback', () => {
      const tracker = new VisibilityTracker(visibilityCallback)

      expect(tracker).toBeDefined()
    })
  })

  describe('start', () => {
    test('adds visibilitychange event listener', () => {
      const tracker = new VisibilityTracker(visibilityCallback)

      tracker.start()

      expect(mockDocument.addEventListener).toHaveBeenCalledWith(
        'visibilitychange',
        expect.any(Function)
      )
    })

    test('calls callback when visibility changes to hidden', () => {
      const tracker = new VisibilityTracker(visibilityCallback)
      tracker.start()

      // Simulate visibility change to hidden
      mockDocument.hidden = true
      visibilityChangeListeners[0]()

      expect(visibilityCallback).toHaveBeenCalledWith(false)
    })

    test('calls callback when visibility changes to visible', () => {
      mockDocument.hidden = true
      const tracker = new VisibilityTracker(visibilityCallback)
      tracker.start()

      // Simulate visibility change to visible
      mockDocument.hidden = false
      visibilityChangeListeners[0]()

      expect(visibilityCallback).toHaveBeenCalledWith(true)
    })

    test('handles multiple visibility changes', () => {
      const tracker = new VisibilityTracker(visibilityCallback)
      tracker.start()

      // Change to hidden
      mockDocument.hidden = true
      visibilityChangeListeners[0]()

      // Change to visible
      mockDocument.hidden = false
      visibilityChangeListeners[0]()

      // Change to hidden again
      mockDocument.hidden = true
      visibilityChangeListeners[0]()

      expect(visibilityCallback).toHaveBeenCalledTimes(3)
      expect(visibilityCallback).toHaveBeenNthCalledWith(1, false)
      expect(visibilityCallback).toHaveBeenNthCalledWith(2, true)
      expect(visibilityCallback).toHaveBeenNthCalledWith(3, false)
    })

    test('is idempotent - calling start multiple times only adds listener once', () => {
      const tracker = new VisibilityTracker(visibilityCallback)

      tracker.start()
      tracker.start()
      tracker.start()

      expect(mockDocument.addEventListener).toHaveBeenCalledTimes(3)
      // But only one listener should be active (last one replaces previous)
      expect(visibilityChangeListeners.length).toBe(3)
    })
  })

  describe('stop', () => {
    test('removes visibilitychange event listener', () => {
      const tracker = new VisibilityTracker(visibilityCallback)
      tracker.start()

      tracker.stop()

      expect(mockDocument.removeEventListener).toHaveBeenCalledWith(
        'visibilitychange',
        expect.any(Function)
      )
    })

    test('prevents callback from being called after stop', () => {
      const tracker = new VisibilityTracker(visibilityCallback)
      tracker.start()
      tracker.stop()

      // Try to trigger visibility change
      mockDocument.hidden = true
      if (visibilityChangeListeners[0]) {
        visibilityChangeListeners[0]()
      }

      expect(visibilityCallback).not.toHaveBeenCalled()
    })

    test('is idempotent - calling stop multiple times is safe', () => {
      const tracker = new VisibilityTracker(visibilityCallback)
      tracker.start()

      tracker.stop()
      tracker.stop()
      tracker.stop()

      // Only removes listener once (correctly idempotent)
      expect(mockDocument.removeEventListener).toHaveBeenCalledTimes(1)
    })

    test('can be called before start without error', () => {
      const tracker = new VisibilityTracker(visibilityCallback)

      expect(() => tracker.stop()).not.toThrow()
    })
  })

  describe('isVisible', () => {
    test('returns true when document is visible', () => {
      mockDocument.hidden = false
      const tracker = new VisibilityTracker(visibilityCallback)

      const result = tracker.isVisible()

      expect(result).toBe(true)
    })

    test('returns false when document is hidden', () => {
      mockDocument.hidden = true
      const tracker = new VisibilityTracker(visibilityCallback)

      const result = tracker.isVisible()

      expect(result).toBe(false)
    })

    test('works before start is called', () => {
      mockDocument.hidden = false
      const tracker = new VisibilityTracker(visibilityCallback)

      const result = tracker.isVisible()

      expect(result).toBe(true)
    })

    test('reflects current visibility state', () => {
      const tracker = new VisibilityTracker(visibilityCallback)
      tracker.start()

      // Initially visible
      mockDocument.hidden = false
      expect(tracker.isVisible()).toBe(true)

      // Change to hidden
      mockDocument.hidden = true
      expect(tracker.isVisible()).toBe(false)

      // Change back to visible
      mockDocument.hidden = false
      expect(tracker.isVisible()).toBe(true)
    })
  })
})
