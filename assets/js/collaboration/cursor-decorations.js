/**
 * Cursor Decoration Factory
 *
 * Responsibility: Create ProseMirror decorations for remote cursors and selections.
 * Follows Single Responsibility Principle - only handles decoration creation.
 *
 * @module CursorDecorations
 */

import { Decoration } from '@milkdown/prose/view'

/**
 * Create a cursor widget element.
 *
 * @private
 * @param {string} userId - User identifier
 * @param {string} userName - User display name
 * @param {string} color - Hex color code
 * @returns {HTMLElement} Cursor widget element
 */
function createCursorElement(userId, userName, color) {
  const cursorEl = document.createElement('span')
  cursorEl.className = 'remote-cursor'
  cursorEl.style.borderLeftColor = color

  const labelEl = document.createElement('span')
  labelEl.className = 'remote-cursor-label'
  labelEl.style.backgroundColor = color
  labelEl.textContent = userName || userId.substring(0, 8)

  cursorEl.appendChild(labelEl)

  return cursorEl
}

/**
 * Create a cursor widget decoration.
 *
 * @param {string} userId - User identifier
 * @param {string} userName - User display name
 * @param {string} color - Hex color code
 * @param {number} position - Document position for cursor
 * @returns {Decoration} ProseMirror decoration
 */
export function createCursorWidget(userId, userName, color, position) {
  const cursorEl = createCursorElement(userId, userName, color)

  return Decoration.widget(position, cursorEl, {
    side: -1,
    key: `cursor-${userId}`
  })
}

/**
 * Create a selection decoration.
 *
 * @param {string} userId - User identifier
 * @param {string} color - Hex color code
 * @param {number} from - Start position of selection
 * @param {number} to - End position of selection
 * @returns {Decoration} ProseMirror decoration
 */
export function createSelectionDecoration(userId, color, from, to) {
  return Decoration.inline(from, to, {
    class: 'remote-selection',
    style: `background-color: ${color}33;` // 20% opacity
  }, {
    key: `selection-${userId}`
  })
}

/**
 * Create decorations for a user's cursor and selection.
 *
 * @param {Object} userState - User awareness state
 * @param {string} userState.userId - User identifier
 * @param {string} [userState.userName] - User display name
 * @param {Object} userState.selection - Selection state
 * @param {number} userState.selection.anchor - Selection anchor position
 * @param {number} userState.selection.head - Selection head position
 * @param {string} color - Hex color code
 * @returns {Decoration[]} Array of decorations
 */
export function createUserDecorations(userState, color) {
  const { userId, userName, selection } = userState
  const decorations = []

  if (!selection || !userId) {
    return decorations
  }

  // Add selection decoration if there's a range selected
  if (selection.anchor !== selection.head) {
    const from = Math.min(selection.anchor, selection.head)
    const to = Math.max(selection.anchor, selection.head)
    decorations.push(createSelectionDecoration(userId, color, from, to))
  }

  // Add cursor decoration at head position
  decorations.push(createCursorWidget(userId, userName, color, selection.head))

  return decorations
}
