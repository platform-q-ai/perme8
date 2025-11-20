/**
 * Tests for focus-editor event handler
 */

import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest'
import { registerFocusEditorHandler } from '../../event-handlers/focus-editor'

describe('registerFocusEditorHandler', () => {
  let editorContainer: HTMLElement
  let editor: HTMLElement

  beforeEach(() => {
    // Create test editor structure
    editorContainer = document.createElement('div')
    editorContainer.id = 'editor-container'
    
    editor = document.createElement('div')
    editor.className = 'ProseMirror'
    editor.tabIndex = 0 // Make focusable
    
    editorContainer.appendChild(editor)
    document.body.appendChild(editorContainer)
    
    // Mock focus method
    vi.spyOn(editor, 'focus')
  })

  afterEach(() => {
    // Only remove if still in DOM
    if (editorContainer.parentNode) {
      document.body.removeChild(editorContainer)
    }
    vi.restoreAllMocks()
  })

  test('focuses editor after delay on phx:focus-editor event', async () => {
    // Register the handler
    registerFocusEditorHandler()

    // Dispatch the event
    window.dispatchEvent(new CustomEvent('phx:focus-editor'))

    // Should not focus immediately
    expect(editor.focus).not.toHaveBeenCalled()

    // Wait for the 100ms delay
    await new Promise(resolve => setTimeout(resolve, 150))

    // Should have focused the editor
    expect(editor.focus).toHaveBeenCalledTimes(1)
  })

  test('does nothing if editor does not exist', async () => {
    // Remove editor
    document.body.removeChild(editorContainer)

    // Register handler and dispatch event (should not throw)
    registerFocusEditorHandler()
    expect(() => {
      window.dispatchEvent(new CustomEvent('phx:focus-editor'))
    }).not.toThrow()

    // Wait for delay
    await new Promise(resolve => setTimeout(resolve, 150))
  })
})
