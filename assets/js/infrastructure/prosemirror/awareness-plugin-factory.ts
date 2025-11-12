/**
 * AwarenessPluginFactory
 *
 * Factory for creating ProseMirror plugins that render remote user cursors and selections.
 * Integrates Yjs Awareness with ProseMirror decorations to visualize collaborative presence.
 *
 * The plugin:
 * - Listens to awareness changes
 * - Renders cursor decorations for remote users
 * - Applies user colors and names to decorations
 * - Excludes local user from rendering
 * - Cleans up listeners on destroy
 *
 * @example
 * ```typescript
 * import { Awareness } from 'y-protocols/awareness'
 * import { createAwarenessPlugin } from './awareness-plugin-factory'
 *
 * const awareness = new Awareness(ydoc)
 * const plugin = createAwarenessPlugin(awareness, 'user-123')
 *
 * // Add to Milkdown editor
 * const editor = Editor.make()
 *   .config((ctx) => {
 *     ctx.set(editorViewOptions.key, {
 *       plugins: [plugin]
 *     })
 *   })
 * ```
 *
 * @module infrastructure/prosemirror
 */

import { Plugin } from '@milkdown/prose/state'
import { Decoration, DecorationSet } from '@milkdown/prose/view'
import type { Awareness } from 'y-protocols/awareness'

/**
 * Awareness state structure (stored in Yjs Awareness)
 */
interface AwarenessState {
  userId: string
  userName: string
  userColor?: string
  cursor?: number
  selection?: { from: number; to: number; anchor: number; head: number }
}

/**
 * Create a ProseMirror plugin for rendering awareness cursors
 *
 * Creates a plugin that:
 * 1. Listens to awareness changes from Yjs
 * 2. Renders cursor decorations for remote users
 * 3. Excludes the local user from rendering
 * 4. Applies user colors and names
 * 5. Cleans up on destroy
 *
 * @param awareness - Yjs Awareness instance
 * @param userId - Local user ID (to exclude from rendering)
 * @returns ProseMirror Plugin for awareness rendering
 * @throws {Error} If awareness is null
 * @throws {Error} If userId is empty
 *
 * @example
 * ```typescript
 * const awareness = new Awareness(ydoc)
 * const plugin = createAwarenessPlugin(awareness, 'user-123')
 * ```
 */
export function createAwarenessPlugin(awareness: Awareness, userId: string): Plugin {
  if (!awareness) {
    throw new Error('Awareness is required')
  }

  if (!userId || userId.trim() === '') {
    throw new Error('UserId is required')
  }

  /**
   * Create decorations for remote users
   *
   * Filters out local user and users without cursor positions.
   * Creates cursor decorations with user colors and names.
   *
   * @param doc - ProseMirror document
   * @returns DecorationSet with cursor decorations
   */
  function createDecorations(doc: any): DecorationSet {
    const decorations: Decoration[] = []
    const states = awareness.getStates()

    states.forEach((state: { [x: string]: any }, clientId: number) => {
      // Cast to AwarenessState for type safety
      const awarenessState = state as AwarenessState
      // Skip local user
      if (awarenessState.userId === userId) {
        return
      }

      // Skip users without selection
      if (!awarenessState.selection) {
        return
      }

      // Determine user color (fallback to default if not provided)
      const userColor = awarenessState.userColor || `hsl(${(clientId * 137) % 360}, 70%, 60%)`

      // Create cursor decoration at head position
      const cursorPos = awarenessState.selection.head
      const cursorDecoration = Decoration.widget(
        cursorPos,
        () => {
          const cursor = document.createElement('span')
          cursor.className = 'remote-cursor'
          cursor.style.borderLeftColor = userColor
          cursor.setAttribute('data-user-id', awarenessState.userId)
          cursor.setAttribute('data-user-name', awarenessState.userName)

          // Add cursor label with user name
          const label = document.createElement('span')
          label.className = 'remote-cursor-label'
          label.textContent = awarenessState.userName || `User ${awarenessState.userId.substring(0, 6)}`
          label.style.backgroundColor = userColor
          cursor.appendChild(label)

          return cursor
        },
        {
          side: -1
        }
      )

      decorations.push(cursorDecoration)

      // Add selection highlight if there's a range selected
      if (awarenessState.selection.from !== awarenessState.selection.to) {
        const from = Math.min(awarenessState.selection.from, awarenessState.selection.to)
        const to = Math.max(awarenessState.selection.from, awarenessState.selection.to)

        const selectionDecoration = Decoration.inline(
          from,
          to,
          {
            class: 'remote-selection',
            style: `background-color: ${userColor}33;` // 20% opacity
          }
        )

        decorations.push(selectionDecoration)
      }
    })

    return DecorationSet.create(doc, decorations)
  }

  /**
   * ProseMirror Plugin
   */
  const plugin = new Plugin({
    state: {
      init(_, state) {
        return createDecorations(state.doc)
      },
      apply(tr, oldState) {
        // If transaction has awareness update metadata, recreate decorations
        if (tr.getMeta('awarenessUpdate')) {
          return createDecorations(tr.doc)
        }
        // Otherwise, map existing decorations
        return oldState.map(tr.mapping, tr.doc)
      }
    },
    props: {
      decorations(state) {
        return this.getState(state)
      }
    },
    view(editorView) {
      /**
       * Awareness change handler
       *
       * Called when awareness state changes (users join, update, or leave).
       * Dispatches a transaction to trigger plugin state update and re-render decorations.
       */
      const awarenessChangeHandler = (_changes: any) => {
        // Dispatch a transaction with awareness update metadata
        // This will trigger the apply() method above to recreate decorations
        const tr = editorView.state.tr.setMeta('awarenessUpdate', true)
        editorView.dispatch(tr)
      }

      // Register awareness change listener
      awareness.on('change', awarenessChangeHandler)

      return {
        destroy: () => {
          // Unregister awareness listener on view destroy
          awareness.off('change', awarenessChangeHandler)
        }
      }
    }
  })

  return plugin
}
