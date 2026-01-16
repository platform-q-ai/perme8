/**
 * TaskListClickPlugin - Infrastructure Layer
 *
 * Milkdown plugin that enables checkbox toggling for GFM task lists.
 * Handles DOM click events on task list checkboxes and updates the document state.
 *
 * Infrastructure Layer Characteristics:
 * - Integrates with ProseMirror's event handling system
 * - Manages DOM events and document mutations
 * - Provides checkbox toggle behavior for task lists
 *
 * SOLID Principles:
 * - Single Responsibility: Handles checkbox click events only
 * - Open/Closed: Extensible through ProseMirror plugin system
 * - Dependency Inversion: Depends on ProseMirror abstractions
 *
 * @module infrastructure/milkdown
 */

import { $prose } from '@milkdown/utils'
import { Plugin, PluginKey } from '@milkdown/prose/state'
import type { EditorView } from '@milkdown/prose/view'

/**
 * Plugin key for task list click handling
 */
const taskListClickKey = new PluginKey('taskListClick')

/**
 * Find the task list item node at the clicked position
 *
 * @param view - ProseMirror EditorView
 * @param event - DOM click event
 * @returns Position and node if found, null otherwise
 */
function findTaskListItem(view: EditorView, event: MouseEvent) {
  const target = event.target as HTMLElement

  // BUGFIX: Only handle clicks on the checkbox area, not on text content
  // Check if we clicked on or inside a task list item
  const taskListItem = target.closest('li[data-item-type="task"]')
  if (!taskListItem) {
    return null
  }

  // Check if the click target is a paragraph (text content)
  // This prevents text clicks from toggling the checkbox
  if (target.tagName === 'P' || target.closest('p')) {
    // Click was on text content, not the checkbox
    return null
  }

  // If we reach here, click was on the li element itself (not on paragraph),
  // which means it was on the checkbox area. Proceed with toggle.

  // Find the position of the clicked element in the document
  const pos = view.posAtDOM(taskListItem, 0)
  if (pos === null || pos === undefined) {
    return null
  }

  // Get the node at this position
  const $pos = view.state.doc.resolve(pos)
  const node = $pos.node($pos.depth)

  // Verify it's actually a list item with checked attribute
  if (node.type.name !== 'list_item' || node.attrs.checked === null) {
    return null
  }

  return {
    pos: $pos.before($pos.depth),
    node
  }
}

/**
 * Creates a Milkdown plugin that handles checkbox clicks in task lists
 *
 * This plugin:
 * 1. Intercepts click events on task list items
 * 2. Toggles the checked state in the document
 * 3. Updates the DOM to reflect the change
 *
 * Implementation:
 * - Uses ProseMirror's handleDOMEvents to intercept clicks
 * - Uses setNodeMarkup to update the node's checked attribute
 * - Prevents default behavior to avoid cursor positioning issues
 *
 * @returns Milkdown prose plugin
 */
export const taskListClickPlugin = $prose(() => {
  return new Plugin({
    key: taskListClickKey,
    props: {
      handleDOMEvents: {
        /**
         * Handle click events on task list checkboxes
         *
         * @param view - ProseMirror EditorView
         * @param event - DOM click event
         * @returns true if event was handled, false otherwise
         */
         click(view: EditorView, event: MouseEvent): boolean {
          // Only handle clicks on task list items
          const result = findTaskListItem(view, event)
          if (!result) {
            return false
          }

          const { pos, node } = result

          // Toggle the checked state
          const newChecked = !node.attrs.checked

          // Create transaction to update the node's checked attribute
          const tr = view.state.tr.setNodeMarkup(pos, undefined, {
            ...node.attrs,
            checked: newChecked
          })

          // Dispatch the transaction to update the document
          view.dispatch(tr)

          // Prevent default to avoid cursor positioning issues
          event.preventDefault()

          return true
        }
      }
    }
  })
})
