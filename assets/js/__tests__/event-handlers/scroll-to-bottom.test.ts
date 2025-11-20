/**
 * Tests for scroll-to-bottom event handler
 */

import { describe, test, expect, beforeEach, afterEach } from 'vitest'
import { registerScrollToBottomHandler } from '../../event-handlers/scroll-to-bottom'

describe('registerScrollToBottomHandler', () => {
  let container: HTMLElement

  beforeEach(() => {
    // Create test container
    container = document.createElement('div')
    container.id = 'chat-messages'
    container.style.height = '100px'
    container.style.overflow = 'auto'
    
    // Add content that exceeds container height
    const content = document.createElement('div')
    content.style.height = '500px'
    container.appendChild(content)
    
    document.body.appendChild(container)
  })

  afterEach(() => {
    // Only remove if still in DOM
    if (container.parentNode) {
      document.body.removeChild(container)
    }
  })

  test('scrolls chat-messages container to bottom on phx:scroll_to_bottom event', () => {
    // Register the handler
    registerScrollToBottomHandler()

    // Initially scrollTop should be 0
    expect(container.scrollTop).toBe(0)

    // Dispatch the event
    window.dispatchEvent(new CustomEvent('phx:scroll_to_bottom'))

    // Should scroll to bottom (scrollHeight - clientHeight)
    expect(container.scrollTop).toBe(container.scrollHeight - container.clientHeight)
  })

  test('does nothing if chat-messages container does not exist', () => {
    // Remove container
    document.body.removeChild(container)

    // Register handler and dispatch event (should not throw)
    registerScrollToBottomHandler()
    expect(() => {
      window.dispatchEvent(new CustomEvent('phx:scroll_to_bottom'))
    }).not.toThrow()
  })
})
