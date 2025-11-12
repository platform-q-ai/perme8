/**
 * Tests for ChatInputHook (Presentation Layer)
 *
 * Tests Phoenix hook for chat input textarea.
 * Tests keyboard event handling and form submission delegation.
 */

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest'
import { ChatInputHook } from '../../../presentation/hooks/chat-input-hook'

describe('ChatInputHook', () => {
  let hook: ChatInputHook
  let mockTextarea: HTMLTextAreaElement
  let mockForm: HTMLFormElement

  beforeEach(() => {
    // Create mock form
    mockForm = document.createElement('form')
    mockForm.id = 'chat-form'

    // Create mock textarea
    mockTextarea = document.createElement('textarea')
    mockTextarea.id = 'chat-input'
    mockTextarea.value = ''
    mockForm.appendChild(mockTextarea)

    // Attach to DOM (required for happy-dom event dispatching)
    document.body.appendChild(mockForm)

    // Initialize phxPrivate property required by ViewHook
    ;(mockTextarea as any).phxPrivate = {}

    // Create hook instance
    hook = new ChatInputHook(null as any, mockTextarea)
  })

  afterEach(() => {
    // Clean up DOM
    if (mockForm.parentNode) {
      mockForm.parentNode.removeChild(mockForm)
    }

    // Call destroyed lifecycle if hook was mounted
    if (hook.destroyed) {
      hook.destroyed()
    }
  })

  describe('mounted', () => {
    test('attaches keydown event listener', () => {
      const addEventListenerSpy = vi.spyOn(mockTextarea, 'addEventListener')

      hook.mounted()

      expect(addEventListenerSpy).toHaveBeenCalledWith(
        'keydown',
        expect.any(Function)
      )
    })
  })

  describe('Enter key behavior', () => {
    beforeEach(() => {
      hook.mounted()
    })

    test('submits form on Enter without Shift', () => {
      mockTextarea.value = 'Hello, world!'

      // Track if submit event was dispatched (LiveView form submission)
      let submitEventDispatched = false
      let submitEvent: Event | null = null

      mockForm.addEventListener('submit', (e) => {
        submitEventDispatched = true
        submitEvent = e
      })

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      mockTextarea.dispatchEvent(event)

      expect(preventDefaultSpy).toHaveBeenCalled()
      // Verify that a submit event was dispatched (LiveView form submission)
      expect(submitEventDispatched).toBe(true)
      expect(submitEvent).toBeTruthy()
      // Verify event type - TypeScript needs help with type narrowing here
      expect(submitEvent).not.toBeNull()
      if (submitEvent) {
        expect((submitEvent as Event).type).toBe('submit')
      }
    })

    test('does NOT submit on Enter with Shift (new line)', () => {
      mockTextarea.value = 'Hello'

      // Track if submit event was dispatched
      let submitEventDispatched = false
      mockForm.addEventListener('submit', () => {
        submitEventDispatched = true
      })

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: true
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      mockTextarea.dispatchEvent(event)

      expect(preventDefaultSpy).not.toHaveBeenCalled()
      expect(submitEventDispatched).toBe(false)
    })

    test('does NOT submit when input is empty', () => {
      mockTextarea.value = ''

      // Track if submit event was dispatched
      let submitEventDispatched = false
      mockForm.addEventListener('submit', () => {
        submitEventDispatched = true
      })

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false
      })

      mockTextarea.dispatchEvent(event)

      expect(submitEventDispatched).toBe(false)
    })

    test('does NOT submit when input is only whitespace', () => {
      mockTextarea.value = '   \n\t  '

      // Track if submit event was dispatched
      let submitEventDispatched = false
      mockForm.addEventListener('submit', () => {
        submitEventDispatched = true
      })

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false
      })

      mockTextarea.dispatchEvent(event)

      expect(submitEventDispatched).toBe(false)
    })

    test('handles missing form gracefully', () => {
      // Remove textarea from form
      mockTextarea.remove()
      mockTextarea.value = 'Test'

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false
      })

      // Should not throw
      expect(() => mockTextarea.dispatchEvent(event)).not.toThrow()
    })
  })

  describe('other key behavior', () => {
    beforeEach(() => {
      hook.mounted()
    })

    test('allows other keys without preventing default', () => {
      const event = new KeyboardEvent('keydown', {
        key: 'a'
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      mockTextarea.dispatchEvent(event)

      expect(preventDefaultSpy).not.toHaveBeenCalled()
    })

    test('allows Backspace key', () => {
      const event = new KeyboardEvent('keydown', {
        key: 'Backspace'
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      mockTextarea.dispatchEvent(event)

      expect(preventDefaultSpy).not.toHaveBeenCalled()
    })

    test('allows Escape key', () => {
      const event = new KeyboardEvent('keydown', {
        key: 'Escape'
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      mockTextarea.dispatchEvent(event)

      expect(preventDefaultSpy).not.toHaveBeenCalled()
    })
  })

  describe('updated lifecycle', () => {
    test('refocuses input when drawer is open', () => {
      // Create drawer structure
      const drawer = document.createElement('div')
      drawer.classList.add('drawer')

      const drawerCheckbox = document.createElement('input')
      drawerCheckbox.type = 'checkbox'
      drawerCheckbox.id = 'drawer-checkbox'
      drawerCheckbox.checked = true

      drawer.appendChild(drawerCheckbox)
      drawer.appendChild(mockForm)

      document.body.appendChild(drawer)

      hook.mounted()

      // Focus somewhere else
      const otherElement = document.createElement('input')
      document.body.appendChild(otherElement)
      otherElement.focus()
      expect(document.activeElement).toBe(otherElement)

      // Call updated
      hook.updated?.()

      expect(document.activeElement).toBe(mockTextarea)

      // Cleanup
      document.body.removeChild(drawer)
      document.body.removeChild(otherElement)
    })

    test('does NOT refocus when drawer is closed', () => {
      // Create drawer structure
      const drawer = document.createElement('div')
      drawer.classList.add('drawer')

      const drawerCheckbox = document.createElement('input')
      drawerCheckbox.type = 'checkbox'
      drawerCheckbox.id = 'drawer-checkbox'
      drawerCheckbox.checked = false // Drawer closed

      drawer.appendChild(drawerCheckbox)
      drawer.appendChild(mockForm)

      document.body.appendChild(drawer)

      hook.mounted()

      // Focus somewhere else
      const otherElement = document.createElement('input')
      document.body.appendChild(otherElement)
      otherElement.focus()
      expect(document.activeElement).toBe(otherElement)

      // Call updated
      hook.updated?.()

      // Should NOT refocus
      expect(document.activeElement).toBe(otherElement)

      // Cleanup
      document.body.removeChild(drawer)
      document.body.removeChild(otherElement)
    })

    test('handles missing drawer gracefully', () => {
      hook.mounted()

      // Call updated without drawer structure
      expect(() => hook.updated?.()).not.toThrow()
    })
  })

  describe('lifecycle cleanup', () => {
    test('removes keydown event listener on destroyed', () => {
      hook.mounted()
      const removeEventListenerSpy = vi.spyOn(mockTextarea, 'removeEventListener')

      hook.destroyed()

      expect(removeEventListenerSpy).toHaveBeenCalledWith(
        'keydown',
        expect.any(Function)
      )
    })

    test('handles destroyed before mounted', () => {
      expect(() => hook.destroyed()).not.toThrow()
    })
  })

  describe('edge cases', () => {
    test('handles very long message text', () => {
      hook.mounted()
      mockTextarea.value = 'a'.repeat(10000)

      // Track if submit event was dispatched
      let submitEventDispatched = false
      mockForm.addEventListener('submit', () => {
        submitEventDispatched = true
      })

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false
      })

      mockTextarea.dispatchEvent(event)

      expect(submitEventDispatched).toBe(true)
    })

    test('handles multiline message with newlines', () => {
      hook.mounted()
      mockTextarea.value = 'Line 1\nLine 2\nLine 3'

      // Track if submit event was dispatched
      let submitEventDispatched = false
      mockForm.addEventListener('submit', () => {
        submitEventDispatched = true
      })

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false
      })

      mockTextarea.dispatchEvent(event)

      expect(submitEventDispatched).toBe(true)
    })

    test('handles special characters in message', () => {
      hook.mounted()
      mockTextarea.value = '<script>alert("xss")</script>'

      // Track if submit event was dispatched
      let submitEventDispatched = false
      mockForm.addEventListener('submit', () => {
        submitEventDispatched = true
      })

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false
      })

      mockTextarea.dispatchEvent(event)

      expect(submitEventDispatched).toBe(true)
    })
  })
})
