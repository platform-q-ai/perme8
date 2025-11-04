import { Editor, rootCtx, editorViewCtx, defaultValueCtx, serializerCtx } from '@milkdown/core'
import { commonmark } from '@milkdown/preset-commonmark'
import { nord } from '@milkdown/theme-nord'
import { clipboard } from '@milkdown/plugin-clipboard'
import { CollaborationManager } from './collaboration'

/**
 * MilkdownEditor Hook
 *
 * Responsibilities:
 * - UI lifecycle management (mounted/destroyed)
 * - Milkdown editor initialization
 * - Phoenix LiveView communication
 * - Delegates collaboration logic to CollaborationManager
 */
export const MilkdownEditor = {
  mounted() {
    // Get initial state from data attributes
    const initialYjsState = this.el.dataset.yjsState || ''
    const initialContent = this.el.dataset.initialContent || ''

    // Initialize collaboration manager with initial state
    this.collaborationManager = new CollaborationManager()
    this.collaborationManager.initialize(initialYjsState)

    // Debounce timer for database saves
    this.saveTimer = null
    this.SAVE_DEBOUNCE_MS = 2000 // Save 2 seconds after user stops typing

    // Set up callback for local updates to send to server
    this.collaborationManager.onLocalUpdate((updateBase64, userId) => {
      // IMMEDIATELY broadcast update to other clients for real-time collaboration
      this.pushEvent('yjs_update', {
        update: updateBase64,
        user_id: userId
      })

      // DEBOUNCE database saves to prevent race conditions
      if (this.saveTimer) {
        clearTimeout(this.saveTimer)
      }

      this.saveTimer = setTimeout(() => {
        // Extract markdown content and complete state for persistence
        const markdown = this.getMarkdownContent()
        const completeState = this.collaborationManager.getCompleteState()

        this.pushEvent('save_note', {
          complete_state: completeState,
          markdown: markdown
        })
      }, this.SAVE_DEBOUNCE_MS)
    })

    // Set up callback for awareness updates
    this.collaborationManager.onAwarenessUpdate((updateBase64, userId) => {
      this.pushEvent('awareness_update', {
        update: updateBase64,
        user_id: userId
      })
    })

    // Listen for remote Yjs updates from server
    this.handleEvent('yjs_update', ({ update }) => {
      this.collaborationManager.applyRemoteUpdate(update)
    })

    // Listen for remote awareness updates from server
    this.handleEvent('awareness_update', ({ update }) => {
      this.collaborationManager.applyRemoteAwarenessUpdate(update)
    })

    // Create Milkdown editor WITHOUT history/keymap (we'll add them later as raw plugins)
    const editor = Editor.make()
      .config((ctx) => {
        ctx.set(rootCtx, this.el)
      })
      .use(nord)
      .use(commonmark)
      .use(clipboard)

    this.editor = editor

    // Create the editor and configure collaboration
    editor.create().then(() => {
      this.editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        const state = view.state

        // Configure ProseMirror with collaboration + undo/redo plugins
        const newState = this.collaborationManager.configureProseMirrorPlugins(view, state)
        view.updateState(newState)
      })
    }).catch((error) => {
      console.error('Failed to create Milkdown editor:', error)
    })
  },

  getMarkdownContent() {
    if (!this.editor) {
      return ''
    }

    try {
      // Get the markdown content from the editor
      let markdown = ''
      this.editor.action((ctx) => {
        const editorView = ctx.get(editorViewCtx)
        const serializer = ctx.get(serializerCtx)

        if (serializer && editorView) {
          markdown = serializer(editorView.state.doc)
        }
      })
      return markdown
    } catch (error) {
      console.error('Error extracting markdown:', error)
      return ''
    }
  },

  destroyed() {
    // Clear any pending save timer
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
      this.saveTimer = null
    }

    if (this.collaborationManager) {
      this.collaborationManager.destroy()
    }
    if (this.editor) {
      this.editor.destroy()
    }
  }
}

export default {
  MilkdownEditor
}
