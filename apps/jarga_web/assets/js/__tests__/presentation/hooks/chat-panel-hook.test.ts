/**
 * Tests for ChatPanelHook (Presentation Layer)
 *
 * Tests Phoenix hook for chat panel drawer state management.
 * Focuses on DOM event handling and responsive behavior.
 */

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest'
import { ChatPanelHook } from '../../../presentation/hooks/chat-panel-hook'

// Mock localStorage at module level
const mockStorage: Record<string, string> = {}
const localStorageMock = {
  getItem: vi.fn((key: string) => mockStorage[key] ?? null),
  setItem: vi.fn((key: string, value: string) => {
    mockStorage[key] = value
  }),
  removeItem: vi.fn((key: string) => {
    delete mockStorage[key]
  }),
  clear: vi.fn(() => {
    Object.keys(mockStorage).forEach((key) => delete mockStorage[key])
  })
}

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock,
  writable: true
})

describe('ChatPanelHook', () => {
  let hook: ChatPanelHook
  let mockCheckbox: HTMLInputElement
  let mockToggleButton: HTMLButtonElement
  let mockChatInput: HTMLInputElement

  beforeEach(() => {
    // Clear mock storage before each test
    Object.keys(mockStorage).forEach((key) => delete mockStorage[key])
    vi.clearAllMocks()

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

  describe('state persistence across navigation', () => {
    beforeEach(() => {
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })
    })

    test('saves open state to localStorage when user opens panel', () => {
      vi.useFakeTimers()
      hook.mounted()
      mockCheckbox.checked = false

      // User opens panel
      mockCheckbox.click()
      vi.advanceTimersByTime(0)

      expect(mockStorage['chat-panel-open']).toBe('true')
      vi.useRealTimers()
    })

    test('saves closed state to localStorage when user closes panel', () => {
      vi.useFakeTimers()
      hook.mounted()
      mockCheckbox.checked = true

      // User closes panel
      mockCheckbox.click()
      vi.advanceTimersByTime(0)

      expect(mockStorage['chat-panel-open']).toBe('false')
      vi.useRealTimers()
    })

    test('restores open state from localStorage on mount', () => {
      mockStorage['chat-panel-open'] = 'true'

      // Start on mobile where default would be closed
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 768
      })

      hook.mounted()

      expect(mockCheckbox.checked).toBe(true)
    })

    test('restores closed state from localStorage on mount', () => {
      mockStorage['chat-panel-open'] = 'false'

      // Start on desktop where default would be open
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })

      hook.mounted()

      expect(mockCheckbox.checked).toBe(false)
    })

    test('uses responsive default when no localStorage state exists', () => {
      // No localStorage set (mockStorage is empty)
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })

      hook.mounted()

      expect(mockCheckbox.checked).toBe(true) // Desktop default
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

  describe('panel resizing', () => {
    let mockResizeHandle: HTMLDivElement
    let mockPanelContent: HTMLDivElement

    beforeEach(() => {
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1024
      })

      // Create resize handle element
      mockResizeHandle = document.createElement('div')
      mockResizeHandle.id = 'chat-panel-resize-handle'
      document.body.appendChild(mockResizeHandle)

      // Create panel content element
      mockPanelContent = document.createElement('div')
      mockPanelContent.id = 'chat-panel-content'
      mockPanelContent.style.width = '384px' // Default w-96
      document.body.appendChild(mockPanelContent)
    })

    afterEach(() => {
      mockResizeHandle.parentNode?.removeChild(mockResizeHandle)
      mockPanelContent.parentNode?.removeChild(mockPanelContent)
    })

    test('starts resize on mousedown on handle', () => {
      hook.mounted()

      const mousedownEvent = new MouseEvent('mousedown', { clientX: 500 })
      mockResizeHandle.dispatchEvent(mousedownEvent)

      // Should be in resizing state (cursor should change)
      expect(document.body.style.cursor).toBe('col-resize')
    })

    test('resizes panel on mousemove during drag', () => {
      // Mock offsetWidth since jsdom doesn't compute it
      Object.defineProperty(mockPanelContent, 'offsetWidth', {
        value: 384,
        configurable: true
      })

      hook.mounted()

      // Start drag
      const mousedownEvent = new MouseEvent('mousedown', { clientX: 500 })
      mockResizeHandle.dispatchEvent(mousedownEvent)

      // Drag left to make panel wider
      const mousemoveEvent = new MouseEvent('mousemove', { clientX: 400 })
      document.dispatchEvent(mousemoveEvent)

      // Panel should be wider (moved 100px left = 100px wider = 484px)
      expect(parseInt(mockPanelContent.style.width)).toBe(484)
    })

    test('stops resize on mouseup', () => {
      hook.mounted()

      // Start drag
      mockResizeHandle.dispatchEvent(new MouseEvent('mousedown', { clientX: 500 }))
      expect(document.body.style.cursor).toBe('col-resize')

      // Stop drag
      document.dispatchEvent(new MouseEvent('mouseup'))

      expect(document.body.style.cursor).toBe('')
    })

    test('saves panel width to localStorage after resize', () => {
      vi.useFakeTimers()
      hook.mounted()

      // Start drag
      mockResizeHandle.dispatchEvent(new MouseEvent('mousedown', { clientX: 500 }))

      // Drag to resize
      document.dispatchEvent(new MouseEvent('mousemove', { clientX: 400 }))

      // Stop drag
      document.dispatchEvent(new MouseEvent('mouseup'))
      vi.advanceTimersByTime(0)

      expect(mockStorage['chat-panel-width']).toBeDefined()
      vi.useRealTimers()
    })

    test('restores panel width from localStorage on mount', () => {
      mockStorage['chat-panel-width'] = '500'

      hook.mounted()

      expect(mockPanelContent.style.width).toBe('500px')
    })

    test('enforces minimum panel width', () => {
      hook.mounted()

      // Start drag
      mockResizeHandle.dispatchEvent(new MouseEvent('mousedown', { clientX: 500 }))

      // Try to drag far right to make panel very narrow
      document.dispatchEvent(new MouseEvent('mousemove', { clientX: 900 }))

      // Panel should not go below minimum (384px = w-96)
      expect(parseInt(mockPanelContent.style.width)).toBeGreaterThanOrEqual(384)
    })

    test('enforces maximum panel width', () => {
      hook.mounted()

      // Start drag
      mockResizeHandle.dispatchEvent(new MouseEvent('mousedown', { clientX: 500 }))

      // Try to drag far left to make panel very wide
      document.dispatchEvent(new MouseEvent('mousemove', { clientX: 0 }))

      // Panel should not exceed 80% of viewport
      const maxWidth = window.innerWidth * 0.8
      expect(parseInt(mockPanelContent.style.width)).toBeLessThanOrEqual(maxWidth)
    })
  })
})
