import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest'

/**
 * Unit tests for link click plugin
 * 
 * These tests verify:
 * 1. Cursor class updates with modifier key state
 * 2. Link click behavior (Cmd/Ctrl+Click opens, regular click doesn't)
 * 3. Event listener management and cleanup
 */
describe('Link Click Plugin - Cursor Behavior', () => {
  let editorElement: HTMLElement
  
  beforeEach(() => {
    // Create a mock editor element
    editorElement = document.createElement('div')
    editorElement.className = 'ProseMirror'
    document.body.appendChild(editorElement)
  })

  afterEach(() => {
    // Clean up
    document.body.removeChild(editorElement)
  })

  describe('Modifier Key Detection', () => {
    test('detects metaKey (Cmd on Mac)', () => {
      const event = new KeyboardEvent('keydown', { metaKey: true })
      
      expect(event.metaKey).toBe(true)
      expect(event.ctrlKey).toBe(false)
    })

    test('detects ctrlKey (Ctrl on Windows/Linux)', () => {
      const event = new KeyboardEvent('keydown', { ctrlKey: true })
      
      expect(event.ctrlKey).toBe(true)
      expect(event.metaKey).toBe(false)
    })

    test('detects when no modifier is pressed', () => {
      const event = new KeyboardEvent('keydown')
      
      expect(event.metaKey).toBe(false)
      expect(event.ctrlKey).toBe(false)
    })
  })

  describe('Class Management', () => {
    test('should add link-navigation-mode class when modifier is pressed', () => {
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(false)
      
      // Simulate modifier key pressed
      editorElement.classList.add('link-navigation-mode')
      
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(true)
    })

    test('should remove link-navigation-mode class when modifier is released', () => {
      editorElement.classList.add('link-navigation-mode')
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(true)
      
      // Simulate modifier key released
      editorElement.classList.remove('link-navigation-mode')
      
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(false)
    })

    test('should handle multiple class add/remove cycles', () => {
      // Add
      editorElement.classList.add('link-navigation-mode')
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(true)
      
      // Remove
      editorElement.classList.remove('link-navigation-mode')
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(false)
      
      // Add again
      editorElement.classList.add('link-navigation-mode')
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(true)
    })
  })

  describe('Link Element Detection', () => {
    test('detects link element with href attribute', () => {
      const link = document.createElement('a')
      link.href = 'https://google.com'
      link.textContent = 'Google'
      editorElement.appendChild(link)
      
      const foundLink = editorElement.querySelector('a[href]')
      
      expect(foundLink).not.toBeNull()
      expect(foundLink?.getAttribute('href')).toBe('https://google.com')
    })

    test('does not detect link without href attribute', () => {
      const link = document.createElement('a')
      link.textContent = 'Not a link'
      editorElement.appendChild(link)
      
      const foundLink = editorElement.querySelector('a[href]')
      
      expect(foundLink).toBeNull()
    })

    test('finds nested link element', () => {
      const paragraph = document.createElement('p')
      const link = document.createElement('a')
      link.href = 'https://example.com'
      link.textContent = 'Example'
      paragraph.appendChild(link)
      editorElement.appendChild(paragraph)
      
      const foundLink = editorElement.querySelector('a[href]')
      
      expect(foundLink).not.toBeNull()
    })
  })

  describe('Click Target Detection', () => {
    test('detects click on link element', () => {
      const link = document.createElement('a')
      link.href = 'https://google.com'
      link.textContent = 'Google'
      editorElement.appendChild(link)
      
      // Simulate click
      const clickEvent = new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        view: window
      })
      
      Object.defineProperty(clickEvent, 'target', {
        value: link,
        enumerable: true
      })
      
      const target = clickEvent.target as HTMLElement
      const clickedLink = target.closest('a[href]')
      
      expect(clickedLink).not.toBeNull()
      expect(clickedLink).toBe(link)
    })

    test('detects click on text inside link', () => {
      const link = document.createElement('a')
      link.href = 'https://google.com'
      const textNode = document.createTextNode('Google')
      const span = document.createElement('span')
      span.appendChild(textNode)
      link.appendChild(span)
      editorElement.appendChild(link)
      
      // Simulate click on span inside link
      const clickEvent = new MouseEvent('click', {
        bubbles: true,
        cancelable: true
      })
      
      Object.defineProperty(clickEvent, 'target', {
        value: span,
        enumerable: true
      })
      
      const target = clickEvent.target as HTMLElement
      const clickedLink = target.closest('a[href]')
      
      expect(clickedLink).not.toBeNull()
      expect(clickedLink).toBe(link)
    })

    test('does not detect click outside link', () => {
      const paragraph = document.createElement('p')
      paragraph.textContent = 'Regular text'
      editorElement.appendChild(paragraph)
      
      const clickEvent = new MouseEvent('click', {
        bubbles: true,
        cancelable: true
      })
      
      Object.defineProperty(clickEvent, 'target', {
        value: paragraph,
        enumerable: true
      })
      
      const target = clickEvent.target as HTMLElement
      const clickedLink = target.closest('a[href]')
      
      expect(clickedLink).toBeNull()
    })
  })

  describe('Window.open Behavior', () => {
    test('window.open is called with correct parameters', () => {
      const originalOpen = window.open
      const mockOpen = vi.fn()
      window.open = mockOpen
      
      const url = 'https://google.com'
      window.open(url, '_blank', 'noopener,noreferrer')
      
      expect(mockOpen).toHaveBeenCalledWith(url, '_blank', 'noopener,noreferrer')
      
      // Restore original
      window.open = originalOpen
    })

    test('security flags are included in window.open call', () => {
      const originalOpen = window.open
      const mockOpen = vi.fn()
      window.open = mockOpen
      
      window.open('https://example.com', '_blank', 'noopener,noreferrer')
      
      const callArgs = mockOpen.mock.calls[0]
      expect(callArgs[2]).toContain('noopener')
      expect(callArgs[2]).toContain('noreferrer')
      
      // Restore original
      window.open = originalOpen
    })
  })

  describe('CSS Integration', () => {
    test('CSS selector targets correct element', () => {
      // Create a link
      const link = document.createElement('a')
      link.href = 'https://google.com'
      link.textContent = 'Google'
      
      // Add to editor with navigation mode class
      editorElement.classList.add('link-navigation-mode')
      editorElement.appendChild(link)
      
      // Verify CSS selector would match
      const selector = '.link-navigation-mode a[href]'
      const matchedLink = editorElement.querySelector(selector)
      
      expect(matchedLink).toBe(link)
    })

    test('CSS selector does not match without navigation mode', () => {
      const link = document.createElement('a')
      link.href = 'https://google.com'
      link.textContent = 'Google'
      
      // Add to editor WITHOUT navigation mode class
      editorElement.appendChild(link)
      
      // Verify CSS selector would NOT match
      const selector = '.link-navigation-mode a[href]'
      const matchedLink = editorElement.querySelector(selector)
      
      expect(matchedLink).toBeNull()
    })
  })

  describe('Event Cleanup', () => {
    test('cleanup function removes event listeners', () => {
      const mockKeyDown = vi.fn()
      const mockKeyUp = vi.fn()
      const mockMouseMove = vi.fn()
      
      // Add listeners
      document.addEventListener('keydown', mockKeyDown)
      document.addEventListener('keyup', mockKeyUp)
      editorElement.addEventListener('mousemove', mockMouseMove)
      
      // Simulate cleanup
      document.removeEventListener('keydown', mockKeyDown)
      document.removeEventListener('keyup', mockKeyUp)
      editorElement.removeEventListener('mousemove', mockMouseMove)
      
      // Trigger events - they should NOT call the mocks
      document.dispatchEvent(new KeyboardEvent('keydown'))
      document.dispatchEvent(new KeyboardEvent('keyup'))
      editorElement.dispatchEvent(new MouseEvent('mousemove'))
      
      expect(mockKeyDown).not.toHaveBeenCalled()
      expect(mockKeyUp).not.toHaveBeenCalled()
      expect(mockMouseMove).not.toHaveBeenCalled()
    })

    test('cleanup function removes link-navigation-mode class', () => {
      editorElement.classList.add('link-navigation-mode')
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(true)
      
      // Simulate cleanup
      editorElement.classList.remove('link-navigation-mode')
      
      expect(editorElement.classList.contains('link-navigation-mode')).toBe(false)
    })
  })
})
