/**
 * Tests for ChatPanelHook (Presentation Layer)
 *
 * Tests Phoenix hook for chat panel drawer state management.
 * Focuses on DOM event handling and responsive behavior.
 */

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest'
import { ChatPanelHook } from '../../../presentation/hooks/chat-panel-hook'

describe('ChatPanelHook', () => {
  let hook: ChatPanelHook
  let mockCheckbox: HTMLInputElement
  let mockToggleButton: HTMLButtonElement
  let mockChatInput: HTMLInputElement

  beforeEach(() => {
    // Create mock DOM elements
    mockCheckbox = document.createElement('input')
    mockCheckbox.type = 'checkbox'
    mockCheckbox.id = 'chat-panel-checkbox'

    mockToggleButton = document.createElement('button')
    mockToggleButton.id = 'chat-toggle-btn'
    document.body.appendChild(mockToggleButton)

    mockChatInput = document.createElement('input')
    mockChatInput.id = 'chat-input'
    document.body.appendChild(mockChatInput)

    // Initialize phxPrivate property required by ViewHook
    ;(mockCheckbox as any).phxPrivate = {}

    // Create hook instance
    hook = new ChatPanelHook(null as any, mockCheckbox)
  })

  afterEach(() => {
    // Clean up DOM
    if (mockToggleButton.parentNode) {
      mockToggleButton.parentNode.removeChild(mockToggleButton)
    }
    if (mockChatInput.parentNode) {
      mockChatInput.parentNode.removeChild(mockChatInput)
    }

    // Call destroyed lifecycle if hook was mounted
    if (hook.destroyed) {
      hook.destroyed()
    }

    // Restore timers
    vi.useRealTimers()
  })

  describe('mounted', () => {
    test('sets panel open on desktop by default (>= 1024px)', () => {
      // Mock desktop viewport
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })

      hook.mounted()

      expect(mockCheckbox.checked).toBe(true)
    })

    test('sets panel closed on mobile by default (< 1024px)', () => {
      // Mock mobile viewport
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 768
      })

      hook.mounted()

      expect(mockCheckbox.checked).toBe(false)
    })

    test('hides toggle button when panel is open', () => {
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })

      hook.mounted()

      expect(mockToggleButton.classList.contains('hidden')).toBe(true)
    })

    test('shows toggle button when panel is closed', () => {
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 768
      })

      hook.mounted()

      expect(mockToggleButton.classList.contains('hidden')).toBe(false)
    })
  })

  describe('panel state changes', () => {
    beforeEach(() => {
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })
      hook.mounted()
    })

    test('hides toggle button when panel opens', () => {
      mockCheckbox.checked = false
      mockToggleButton.classList.remove('hidden')

      mockCheckbox.checked = true
      mockCheckbox.dispatchEvent(new Event('change'))

      expect(mockToggleButton.classList.contains('hidden')).toBe(true)
    })

    test('shows toggle button when panel closes', () => {
      mockCheckbox.checked = true
      mockToggleButton.classList.add('hidden')

      mockCheckbox.checked = false
      mockCheckbox.dispatchEvent(new Event('change'))

      expect(mockToggleButton.classList.contains('hidden')).toBe(false)
    })

    test('focuses chat input when panel opens', async () => {
      vi.useFakeTimers()
      mockCheckbox.checked = false

      mockCheckbox.checked = true
      mockCheckbox.dispatchEvent(new Event('change'))

      // Wait for setTimeout (150ms)
      vi.advanceTimersByTime(150)

      expect(document.activeElement).toBe(mockChatInput)
      vi.useRealTimers()
    })

    test('does not trigger focus logic when panel closes', async () => {
      vi.useFakeTimers()
      const focusSpy = vi.spyOn(mockChatInput, 'focus')
      mockCheckbox.checked = true

      mockCheckbox.checked = false
      mockCheckbox.dispatchEvent(new Event('change'))

      vi.advanceTimersByTime(150)

      // Focus should not be called when closing
      expect(focusSpy).not.toHaveBeenCalled()
      vi.useRealTimers()
    })
  })

  describe('keyboard shortcuts', () => {
    beforeEach(() => {
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })
      hook.mounted()
    })

    test('toggles panel with Cmd+K on macOS', () => {
      const initialState = mockCheckbox.checked
      const event = new KeyboardEvent('keydown', {
        key: 'k',
        metaKey: true
      })

      document.dispatchEvent(event)

      expect(mockCheckbox.checked).toBe(!initialState)
    })

    test('toggles panel with Ctrl+K on Windows/Linux', () => {
      const initialState = mockCheckbox.checked
      const event = new KeyboardEvent('keydown', {
        key: 'k',
        ctrlKey: true
      })

      document.dispatchEvent(event)

      expect(mockCheckbox.checked).toBe(!initialState)
    })

    test('closes panel with Escape key when open', () => {
      mockCheckbox.checked = true
      const event = new KeyboardEvent('keydown', { key: 'Escape' })

      document.dispatchEvent(event)

      expect(mockCheckbox.checked).toBe(false)
    })

    test('does nothing with Escape when panel is closed', () => {
      mockCheckbox.checked = false
      const event = new KeyboardEvent('keydown', { key: 'Escape' })

      document.dispatchEvent(event)

      expect(mockCheckbox.checked).toBe(false)
    })

    test('prevents default behavior for Cmd/Ctrl+K', () => {
      const event = new KeyboardEvent('keydown', {
        key: 'k',
        metaKey: true
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      document.dispatchEvent(event)

      expect(preventDefaultSpy).toHaveBeenCalled()
    })
  })

  describe('responsive behavior on window resize', () => {
    test('opens panel when resizing from mobile to desktop', () => {
      // Start on mobile
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 768
      })
      hook.mounted()
      expect(mockCheckbox.checked).toBe(false)

      // Resize to desktop
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })
      window.dispatchEvent(new Event('resize'))

      expect(mockCheckbox.checked).toBe(true)
    })

    test('closes panel when resizing from desktop to mobile', () => {
      // Start on desktop
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })
      hook.mounted()
      expect(mockCheckbox.checked).toBe(true)

      // Resize to mobile
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 768
      })
      window.dispatchEvent(new Event('resize'))

      expect(mockCheckbox.checked).toBe(false)
    })

    test('does not auto-adjust after user manually toggles', () => {
      // Start on desktop
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })
      hook.mounted()
      expect(mockCheckbox.checked).toBe(true)

      // User manually closes
      mockCheckbox.click()
      expect(mockCheckbox.checked).toBe(false)

      // Resize to mobile (should NOT auto-adjust since user interacted)
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 768
      })
      window.dispatchEvent(new Event('resize'))

      // Should still be closed (user preference preserved)
      expect(mockCheckbox.checked).toBe(false)
    })
  })

  describe('lifecycle', () => {
    test('cleans up keyboard event listener on destroyed', () => {
      hook.mounted()
      const removeEventListenerSpy = vi.spyOn(document, 'removeEventListener')

      hook.destroyed()

      expect(removeEventListenerSpy).toHaveBeenCalledWith(
        'keydown',
        expect.any(Function)
      )
    })

    test('cleans up resize event listener on destroyed', () => {
      hook.mounted()
      const removeEventListenerSpy = vi.spyOn(window, 'removeEventListener')

      hook.destroyed()

      expect(removeEventListenerSpy).toHaveBeenCalledWith(
        'resize',
        expect.any(Function)
      )
    })

    test('removes change event listener on destroyed', () => {
      hook.mounted()
      const removeEventListenerSpy = vi.spyOn(mockCheckbox, 'removeEventListener')

      hook.destroyed()

      expect(removeEventListenerSpy).toHaveBeenCalledWith(
        'change',
        expect.any(Function)
      )
    })
  })

  describe('edge cases', () => {
    test('handles missing toggle button gracefully', () => {
      // Remove toggle button from DOM
      mockToggleButton.parentNode?.removeChild(mockToggleButton)

      expect(() => hook.mounted()).not.toThrow()
    })

    test('handles missing chat input gracefully when focusing', async () => {
      vi.useFakeTimers()
      // Remove chat input from DOM
      mockChatInput.parentNode?.removeChild(mockChatInput)

      hook.mounted()
      mockCheckbox.checked = true
      mockCheckbox.dispatchEvent(new Event('change'))

      vi.advanceTimersByTime(150)

      // Should not throw even though input is missing
      expect(() => vi.advanceTimersByTime(0)).not.toThrow()
      vi.useRealTimers()
    })

    test('updated lifecycle method updates button visibility', () => {
      hook.mounted()
      mockCheckbox.checked = true
      mockToggleButton.classList.remove('hidden')

      hook.updated?.()

      expect(mockToggleButton.classList.contains('hidden')).toBe(true)
    })
  })
})
