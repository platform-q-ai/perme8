import { Plugin, PluginKey } from '@milkdown/prose/state'
import { DecorationSet } from '@milkdown/prose/view'
import { getUserColor } from './user-colors'
import { createUserDecorations } from './cursor-decorations'

/**
 * Awareness Plugin for ProseMirror
 *
 * Responsibility: Manage the display of remote user cursors and selections.
 * Follows Single Responsibility Principle - only handles awareness plugin logic.
 *
 * This plugin:
 * - Listens for awareness state changes via transaction metadata
 * - Creates decorations for remote users' cursors and selections
 * - Maps decorations through document changes
 *
 * @module AwarenessPlugin
 */

const awarenessPluginKey = new PluginKey('awareness')

/**
 * Create decorations for all remote users.
 *
 * @private
 * @param {Awareness} awareness - Yjs Awareness instance
 * @param {string} localUserId - ID of the local user
 * @returns {Decoration[]} Array of decorations
 */
function createRemoteUserDecorations(awareness, localUserId) {
  const decorations = []
  const awarenessStates = awareness.getStates()

  awarenessStates.forEach((state, clientId) => {
    // Skip local user
    if (state.userId === localUserId) return

    const color = getUserColor(state.userId)
    const userDecorations = createUserDecorations(state, color)
    decorations.push(...userDecorations)
  })

  return decorations
}

/**
 * Create the awareness ProseMirror plugin.
 *
 * @param {Awareness} awareness - Yjs Awareness instance
 * @param {string} localUserId - ID of the local user
 * @returns {Plugin} ProseMirror plugin
 */
export function createAwarenessPlugin(awareness, localUserId) {
  return new Plugin({
    key: awarenessPluginKey,

    state: {
      init() {
        return DecorationSet.empty
      },

      apply(tr, set) {
        // Check if awareness state changed
        const awarenessChanged = tr.getMeta('awarenessChanged')

        if (awarenessChanged) {
          const decorations = createRemoteUserDecorations(awareness, localUserId)
          return DecorationSet.create(tr.doc, decorations)
        }

        // Map decorations through document changes
        return set.map(tr.mapping, tr.doc)
      }
    },

    props: {
      decorations(state) {
        return this.getState(state)
      }
    }
  })
}

export { awarenessPluginKey }
