import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { ChatPanel, ChatMessages, ChatInput } from '../../chat/chat_hooks'

describe('ChatPanel Hook', () => {
  let hook
  let mockCheckbox
  let mockToggleBtn
  let mockInput

  beforeEach(() => {
    // Create mock checkbox element
    mockCheckbox = document.createElement('input')
    mockCheckbox.type = 'checkbox'
    mockCheckbox.id = 'chat-panel-checkbox'

    // Create mock toggle button
    mockToggleBtn = document.createElement('button')
    mockToggleBtn.id = 'chat-toggle-btn'
    mockToggleBtn.classList.add('hidden')

    // Create mock input
    mockInput = document.createElement('input')
    mockInput.id = 'chat-input'

    // Add to DOM
    document.body.appendChild(mockCheckbox)
    document.body.appendChild(mockToggleBtn)
    document.body.appendChild(mockInput)

    // Create hook instance
    hook = Object.create(ChatPanel)
    hook.el = mockCheckbox

    // Mock localStorage - return null by default (not undefined)
    // so it doesn't override checkbox state in mounted()
    global.localStorage = {
      getItem: vi.fn(() => null),
      setItem: vi.fn()
    }

    // Mock setTimeout
    vi.useFakeTimers()

    // Clear all mocks
    vi.clearAllMocks()
  })

  afterEach(() => {
    // Clean up DOM
    document.body.removeChild(mockCheckbox)
    document.body.removeChild(mockToggleBtn)
    document.body.removeChild(mockInput)

    // Clean up timers
    vi.useRealTimers()

    // Remove event listeners
    if (hook.handleKeyboard) {
      document.removeEventListener('keydown', hook.handleKeyboard)
    }
  })

  describe('mounted', () => {
    it('should find toggle button on mount', () => {
      hook.mounted()

      expect(hook.toggleBtn).toBe(mockToggleBtn)
    })

    it('should hide toggle button when checkbox is checked', () => {
      mockCheckbox.checked = true
      hook.mounted()

      expect(mockToggleBtn.classList.contains('hidden')).toBe(true)
    })

    it('should show toggle button when checkbox is unchecked', () => {
      mockToggleBtn.classList.add('hidden')
      // Mock mobile viewport to keep drawer closed after mount
      global.innerWidth = 768

      hook.mounted()

      // On mobile, drawer defaults to closed, so toggle button should be visible
      expect(mockCheckbox.checked).toBe(false)
      expect(mockToggleBtn.classList.contains('hidden')).toBe(false)
    })

    it('should set initial state to open on desktop', () => {
      // Mock desktop viewport
      global.innerWidth = 1024

      hook.mounted()

      expect(mockCheckbox.checked).toBe(true)
    })

    it('should set initial state to closed on mobile', () => {
      // Mock mobile viewport
      global.innerWidth = 768

      hook.mounted()

      expect(mockCheckbox.checked).toBe(false)
    })

    it('should mark user interaction on checkbox click', () => {
      hook.mounted()

      expect(hook.userInteracted).toBe(false)

      mockCheckbox.click()

      expect(hook.userInteracted).toBe(true)
    })

    it('should not auto-adjust after user interaction', () => {
      global.innerWidth = 1024
      hook.mounted()

      // User closes the panel
      mockCheckbox.click()
      expect(hook.userInteracted).toBe(true)

      // Simulate resize to mobile
      global.innerWidth = 768
      window.dispatchEvent(new Event('resize'))

      // Should NOT auto-adjust because user interacted
      expect(mockCheckbox.checked).toBe(false)
    })

    it('should set initial state based on viewport size', () => {
      // Desktop viewport
      global.innerWidth = 1024

      hook.mounted()

      // Desktop defaults to open
      expect(mockCheckbox.checked).toBe(true)
    })

    it('should focus input when drawer opens', () => {
      const focusSpy = vi.spyOn(mockInput, 'focus')
      hook.mounted()

      mockCheckbox.checked = true
      mockCheckbox.dispatchEvent(new Event('change'))

      // Fast-forward timers
      vi.advanceTimersByTime(150)

      expect(focusSpy).toHaveBeenCalled()
    })

    it('should not focus input before animation completes', () => {
      const focusSpy = vi.spyOn(mockInput, 'focus')
      hook.mounted()

      mockCheckbox.checked = true
      mockCheckbox.dispatchEvent(new Event('change'))

      // Fast-forward only 100ms (not enough)
      vi.advanceTimersByTime(100)

      expect(focusSpy).not.toHaveBeenCalled()
    })

    it('should register keyboard shortcut Cmd+K', () => {
      const clickSpy = vi.spyOn(mockCheckbox, 'click')
      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'k',
        metaKey: true
      })
      document.dispatchEvent(event)

      expect(clickSpy).toHaveBeenCalled()
    })

    it('should register keyboard shortcut Ctrl+K', () => {
      const clickSpy = vi.spyOn(mockCheckbox, 'click')
      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'k',
        ctrlKey: true
      })
      document.dispatchEvent(event)

      expect(clickSpy).toHaveBeenCalled()
    })

    it('should close drawer on Escape when open', () => {
      const clickSpy = vi.spyOn(mockCheckbox, 'click')
      mockCheckbox.checked = true
      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Escape'
      })
      document.dispatchEvent(event)

      expect(clickSpy).toHaveBeenCalled()
    })

    it('should not close drawer on Escape when already closed', () => {
      const clickSpy = vi.spyOn(mockCheckbox, 'click')
      // Mock mobile viewport to ensure drawer is closed by default
      global.innerWidth = 768
      hook.mounted()

      // Drawer should be closed on mobile
      expect(mockCheckbox.checked).toBe(false)

      const event = new KeyboardEvent('keydown', {
        key: 'Escape'
      })
      document.dispatchEvent(event)

      expect(clickSpy).not.toHaveBeenCalled()
    })

    it('should update button visibility when toggle button is initially missing', () => {
      // Remove toggle button
      document.body.removeChild(mockToggleBtn)

      hook.mounted()

      // Toggle button reference should be null initially
      expect(hook.toggleBtn).toBeNull()

      // Re-add toggle button to DOM
      document.body.appendChild(mockToggleBtn)

      // Trigger button visibility update
      hook.updateButtonVisibility()

      // Should find the button now
      expect(hook.toggleBtn).toBe(mockToggleBtn)
    })
  })

  describe('updated', () => {
    it('should update button visibility on LiveView update', () => {
      hook.mounted()
      const updateSpy = vi.spyOn(hook, 'updateButtonVisibility')

      hook.updated()

      expect(updateSpy).toHaveBeenCalled()
    })

    it('should handle missing updateButtonVisibility gracefully', () => {
      hook.updateButtonVisibility = null

      expect(() => {
        hook.updated()
      }).not.toThrow()
    })
  })

  describe('destroyed', () => {
    it('should remove keyboard event listener', () => {
      hook.mounted()
      const removeListenerSpy = vi.spyOn(document, 'removeEventListener')

      hook.destroyed()

      expect(removeListenerSpy).toHaveBeenCalledWith('keydown', hook.handleKeyboard)
    })

    it('should handle missing handleKeyboard gracefully', () => {
      hook.handleKeyboard = null

      expect(() => {
        hook.destroyed()
      }).not.toThrow()
    })
  })
})

describe('ChatMessages Hook', () => {
  let hook
  let mockElement

  beforeEach(() => {
    mockElement = document.createElement('div')
    mockElement.id = 'chat-messages'
    mockElement.style.height = '200px'
    mockElement.style.overflowY = 'auto'

    // Add some content to make it scrollable
    for (let i = 0; i < 50; i++) {
      const message = document.createElement('div')
      message.textContent = `Message ${i}`
      message.style.height = '50px'
      mockElement.appendChild(message)
    }

    document.body.appendChild(mockElement)

    hook = Object.create(ChatMessages)
    hook.el = mockElement
  })

  afterEach(() => {
    document.body.removeChild(mockElement)
  })

  describe('mounted', () => {
    it('should scroll to bottom on mount', () => {
      hook.mounted()

      expect(hook.el.scrollTop).toBe(hook.el.scrollHeight)
    })
  })

  describe('updated', () => {
    it('should scroll to bottom on update', () => {
      // Set scroll to top
      hook.el.scrollTop = 0

      hook.updated()

      expect(hook.el.scrollTop).toBe(hook.el.scrollHeight)
    })
  })

  describe('scrollToBottom', () => {
    it('should set scrollTop to scrollHeight', () => {
      hook.el.scrollTop = 100

      hook.scrollToBottom()

      expect(hook.el.scrollTop).toBe(hook.el.scrollHeight)
    })
  })
})

describe('ChatInput Hook', () => {
  let hook
  let mockTextarea
  let mockForm
  let mockCheckbox

  beforeEach(() => {
    // Create mock form
    mockForm = document.createElement('form')

    // Create mock textarea
    mockTextarea = document.createElement('textarea')
    mockTextarea.id = 'chat-input'
    mockTextarea.value = ''

    // Create mock drawer structure
    const drawer = document.createElement('div')
    drawer.classList.add('drawer')

    mockCheckbox = document.createElement('input')
    mockCheckbox.type = 'checkbox'
    mockCheckbox.id = 'drawer-checkbox'
    mockCheckbox.checked = true

    drawer.appendChild(mockCheckbox)
    drawer.appendChild(mockForm)
    mockForm.appendChild(mockTextarea)

    document.body.appendChild(drawer)

    hook = Object.create(ChatInput)
    hook.el = mockTextarea

    vi.clearAllMocks()
  })

  afterEach(() => {
    const drawer = document.querySelector('.drawer')
    if (drawer) {
      document.body.removeChild(drawer)
    }
  })

  describe('mounted', () => {
    it('should submit form on Enter without Shift', () => {
      // Listen for submit event instead of spying on dispatchEvent
      const submitHandler = vi.fn()
      mockForm.addEventListener('submit', submitHandler)
      mockTextarea.value = 'Test message'

      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false,
        bubbles: true,
        cancelable: true
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      mockTextarea.dispatchEvent(event)

      expect(preventDefaultSpy).toHaveBeenCalled()
      expect(submitHandler).toHaveBeenCalled()
    })

    it('should not submit form on Shift+Enter', () => {
      // Listen for submit event instead of spying on dispatchEvent
      const submitHandler = vi.fn()
      mockForm.addEventListener('submit', submitHandler)
      mockTextarea.value = 'Test message'

      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: true,
        bubbles: true,
        cancelable: true
      })

      mockTextarea.dispatchEvent(event)

      expect(submitHandler).not.toHaveBeenCalled()
    })

    it('should not submit empty message', () => {
      // Listen for submit event instead of spying on dispatchEvent
      const submitHandler = vi.fn()
      mockForm.addEventListener('submit', submitHandler)
      mockTextarea.value = '   '

      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false,
        bubbles: true,
        cancelable: true
      })

      mockTextarea.dispatchEvent(event)

      expect(submitHandler).not.toHaveBeenCalled()
    })

    it('should handle missing form gracefully', () => {
      // Remove form
      const drawer = document.querySelector('.drawer')
      drawer.removeChild(mockForm)
      document.body.appendChild(mockTextarea)

      mockTextarea.value = 'Test'

      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: false,
        bubbles: true,
        cancelable: true
      })

      expect(() => {
        mockTextarea.dispatchEvent(event)
      }).not.toThrow()
    })
  })

  describe('updated', () => {
    it('should refocus input if drawer is open', () => {
      const focusSpy = vi.spyOn(mockTextarea, 'focus')
      mockCheckbox.checked = true

      hook.updated()

      expect(focusSpy).toHaveBeenCalled()
    })

    it('should not focus if drawer is closed', () => {
      const focusSpy = vi.spyOn(mockTextarea, 'focus')
      mockCheckbox.checked = false

      hook.updated()

      expect(focusSpy).not.toHaveBeenCalled()
    })

    it('should not refocus if already focused', () => {
      mockCheckbox.checked = true
      mockTextarea.focus()

      // Create spy AFTER focusing so we don't count the initial focus call
      const focusSpy = vi.spyOn(mockTextarea, 'focus')

      hook.updated()

      // Should not call focus again if already focused
      expect(focusSpy).not.toHaveBeenCalled()
    })
  })
})
