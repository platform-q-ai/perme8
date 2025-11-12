import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest'
import { DocumentTitleHook } from '../../../presentation/hooks/document-title-hook'

describe('DocumentTitleHook', () => {
  let hook: DocumentTitleHook
  let mockInputElement: HTMLInputElement
  let mockEditorElement: HTMLElement

  beforeEach(() => {
    // Create mock DOM elements
    mockInputElement = document.createElement('input')
    mockInputElement.type = 'text'
    mockInputElement.value = 'Test Document'

    mockEditorElement = document.createElement('div')
    mockEditorElement.className = 'ProseMirror'
    mockEditorElement.tabIndex = -1

    const editorContainer = document.createElement('div')
    editorContainer.id = 'editor-container'
    editorContainer.appendChild(mockEditorElement)

    document.body.appendChild(editorContainer)
    document.body.appendChild(mockInputElement)

    // Initialize phxPrivate property required by ViewHook
    ;(mockInputElement as any).phxPrivate = {}

    // Create hook instance
    hook = new DocumentTitleHook(null as any, mockInputElement)
  })

  afterEach(() => {
    // Clean up DOM
    document.body.innerHTML = ''
  })

  describe('mounted', () => {
    test('adds keydown event listener to input element', () => {
      const addEventListenerSpy = vi.spyOn(mockInputElement, 'addEventListener')

      hook.mounted()

      expect(addEventListenerSpy).toHaveBeenCalledWith('keydown', expect.any(Function))
    })
  })

  describe('Enter key handling', () => {
    beforeEach(() => {
      hook.mounted()
    })

    test('prevents default Enter key behavior', () => {
      const event = new KeyboardEvent('keydown', { key: 'Enter' })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      mockInputElement.dispatchEvent(event)

      expect(preventDefaultSpy).toHaveBeenCalled()
    })

    test('blurs the input element on Enter key', () => {
      const blurSpy = vi.spyOn(mockInputElement, 'blur')
      const event = new KeyboardEvent('keydown', { key: 'Enter' })

      mockInputElement.dispatchEvent(event)

      expect(blurSpy).toHaveBeenCalled()
    })

    test('focuses the editor after Enter key', async () => {
      const focusSpy = vi.spyOn(mockEditorElement, 'focus')
      const event = new KeyboardEvent('keydown', { key: 'Enter' })

      mockInputElement.dispatchEvent(event)

      // Wait for setTimeout to complete
      await new Promise(resolve => setTimeout(resolve, 150))

      expect(focusSpy).toHaveBeenCalled()
    })

    test('does not blur or focus on non-Enter keys', () => {
      const blurSpy = vi.spyOn(mockInputElement, 'blur')
      const focusSpy = vi.spyOn(mockEditorElement, 'focus')
      const event = new KeyboardEvent('keydown', { key: 'a' })

      mockInputElement.dispatchEvent(event)

      expect(blurSpy).not.toHaveBeenCalled()
      expect(focusSpy).not.toHaveBeenCalled()
    })

    test('handles case when editor element not found gracefully', async () => {
      // Remove editor from DOM
      document.body.innerHTML = ''
      document.body.appendChild(mockInputElement)

      const event = new KeyboardEvent('keydown', { key: 'Enter' })

      // Should not throw
      expect(() => {
        mockInputElement.dispatchEvent(event)
      }).not.toThrow()

      // Wait for setTimeout
      await new Promise(resolve => setTimeout(resolve, 150))
    })
  })

  describe('Escape key handling', () => {
    beforeEach(() => {
      hook.mounted()
    })

    test('blurs the input on Escape key', () => {
      const blurSpy = vi.spyOn(mockInputElement, 'blur')
      const event = new KeyboardEvent('keydown', { key: 'Escape' })

      mockInputElement.dispatchEvent(event)

      expect(blurSpy).toHaveBeenCalled()
    })

    test('prevents default Escape key behavior', () => {
      const event = new KeyboardEvent('keydown', { key: 'Escape' })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      mockInputElement.dispatchEvent(event)

      expect(preventDefaultSpy).toHaveBeenCalled()
    })

    test('does not focus editor on Escape key', async () => {
      const focusSpy = vi.spyOn(mockEditorElement, 'focus')
      const event = new KeyboardEvent('keydown', { key: 'Escape' })

      mockInputElement.dispatchEvent(event)

      // Wait for setTimeout
      await new Promise(resolve => setTimeout(resolve, 150))

      expect(focusSpy).not.toHaveBeenCalled()
    })
  })

  describe('destroyed', () => {
    test('removes keydown event listener from input element', () => {
      hook.mounted()
      const removeEventListenerSpy = vi.spyOn(mockInputElement, 'removeEventListener')

      hook.destroyed()

      expect(removeEventListenerSpy).toHaveBeenCalledWith('keydown', expect.any(Function))
    })

    test('does not trigger handlers after destroyed', () => {
      hook.mounted()
      hook.destroyed()

      const blurSpy = vi.spyOn(mockInputElement, 'blur')
      const event = new KeyboardEvent('keydown', { key: 'Enter' })

      mockInputElement.dispatchEvent(event)

      expect(blurSpy).not.toHaveBeenCalled()
    })
  })
})
