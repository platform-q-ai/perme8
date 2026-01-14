/**
 * LinkClickPlugin - Infrastructure Layer
 *
 * Milkdown plugin that enables Cmd/Ctrl+Click to open links in new tabs with
 * visual feedback through cursor changes.
 *
 * In contentEditable mode, regular clicks place the cursor for editing.
 * This plugin allows users to follow links by holding Cmd (Mac) or Ctrl (Windows/Linux).
 *
 * Behavior:
 * - **Regular hover over link:** Cursor shows as text cursor (I-beam)
 * - **Hover over link with Cmd/Ctrl held:** Cursor changes to pointer (hand)
 * - **Regular click on link:** Places cursor in link text (for editing)
 * - **Cmd+Click (Mac):** Opens link in new tab
 * - **Ctrl+Click (Windows/Linux):** Opens link in new tab
 *
 * Visual Feedback:
 * - Tracks modifier key state (Cmd/Ctrl) via keyboard events
 * - Adds "link-navigation-mode" class to editor when modifier is pressed
 * - CSS changes cursor from text to pointer on links when class is present
 * - Provides discoverable UX - users see cursor change and try clicking
 *
 * This is the standard behavior in most rich text editors (Google Docs, Notion, etc.)
 * and provides a good user experience for both editing and navigation.
 *
 * Infrastructure Layer Characteristics:
 * - Integrates with ProseMirror's event handling system
 * - Manages DOM events for link navigation
 * - Provides standard editor link navigation behavior
 * - Manages event listeners with proper cleanup
 *
 * SOLID Principles:
 * - Single Responsibility: Handles link click events and cursor feedback
 * - Open/Closed: Extensible through ProseMirror plugin system
 * - Dependency Inversion: Depends on ProseMirror abstractions
 *
 * @module infrastructure/milkdown
 */

import { $prose } from '@milkdown/utils'
import { Plugin, PluginKey } from '@milkdown/prose/state'
import type { EditorView } from '@milkdown/prose/view'

/**
 * Plugin key for link click handling
 */
const linkClickKey = new PluginKey('linkClick')

/**
 * Handle click events on links
 *
 * @param view - ProseMirror EditorView
 * @param event - DOM click event
 * @returns true if event was handled, false otherwise
 */
function handleLinkClick(_view: EditorView, event: MouseEvent): boolean {
  const target = event.target as HTMLElement

  // Only handle if Cmd (Mac) or Ctrl (Windows/Linux) is pressed
  const isModifierPressed = event.metaKey || event.ctrlKey
  if (!isModifierPressed) {
    // Regular click - let editor handle it (place cursor)
    return false
  }

  // Check if we clicked on a link
  const link = target.closest('a[href]') as HTMLAnchorElement | null
  if (!link) {
    // Not a link, ignore
    return false
  }

  // Get the href attribute
  const href = link.getAttribute('href')
  if (!href) {
    // No href, ignore
    return false
  }

  // Prevent default link behavior and editor behavior
  event.preventDefault()
  event.stopPropagation()

  // Open link in new tab
  window.open(href, '_blank', 'noopener,noreferrer')

  return true
}

/**
 * Update cursor style based on whether modifier key is pressed
 * and mouse is hovering over a link
 *
 * @param editorElement - The editor DOM element
 * @param event - Keyboard or mouse event
 */
function updateLinkCursor(editorElement: HTMLElement, event: KeyboardEvent | MouseEvent) {
  const isModifierPressed = event.metaKey || event.ctrlKey

  if (isModifierPressed) {
    // Modifier is pressed - add class that makes links show pointer cursor
    editorElement.classList.add('link-navigation-mode')
  } else {
    // Modifier is not pressed - remove class
    editorElement.classList.remove('link-navigation-mode')
  }
}

/**
 * Set up keyboard event listeners for modifier key tracking
 * This enables the cursor to change when Cmd/Ctrl is pressed
 *
 * @param editorElement - The editor DOM element
 */
function setupModifierKeyTracking(editorElement: HTMLElement) {
  // Track keydown to detect when modifier is pressed
  const handleKeyDown = (event: KeyboardEvent) => {
    updateLinkCursor(editorElement, event)
  }

  // Track keyup to detect when modifier is released
  const handleKeyUp = (event: KeyboardEvent) => {
    updateLinkCursor(editorElement, event)
  }

  // Track mouse movement to update cursor when hovering with modifier already pressed
  const handleMouseMove = (event: MouseEvent) => {
    updateLinkCursor(editorElement, event)
  }

  // Add event listeners
  document.addEventListener('keydown', handleKeyDown)
  document.addEventListener('keyup', handleKeyUp)
  editorElement.addEventListener('mousemove', handleMouseMove)

  // Return cleanup function
  return () => {
    document.removeEventListener('keydown', handleKeyDown)
    document.removeEventListener('keyup', handleKeyUp)
    editorElement.removeEventListener('mousemove', handleMouseMove)
    editorElement.classList.remove('link-navigation-mode')
  }
}

/**
 * Milkdown plugin for handling link clicks with Cmd/Ctrl modifier
 *
 * Usage:
 * - Regular click: Places cursor in link text (for editing)
 * - Cmd+Click (Mac) or Ctrl+Click (Windows/Linux): Opens link in new tab
 * - Cursor changes to pointer when hovering over links with Cmd/Ctrl pressed
 */
export const linkClickPlugin = $prose(() => {
  let cleanup: (() => void) | null = null

  return new Plugin({
    key: linkClickKey,
    props: {
      /**
       * Handle DOM click events
       */
      handleClick(view: EditorView, _pos: number, event: MouseEvent): boolean {
        return handleLinkClick(view, event)
      },
    },
    view(editorView: EditorView) {
      // Set up modifier key tracking when view is created
      cleanup = setupModifierKeyTracking(editorView.dom as HTMLElement)

      return {
        // Clean up event listeners when view is destroyed
        destroy() {
          if (cleanup) {
            cleanup()
            cleanup = null
          }
        },
      }
    },
  })
})
