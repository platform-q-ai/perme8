import { Editor, rootCtx, editorViewCtx, defaultValueCtx, serializerCtx } from '@milkdown/core'
import { commonmark } from '@milkdown/preset-commonmark'
import { gfm } from '@milkdown/preset-gfm'
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
    const readonly = this.el.dataset.readonly === 'true'

    this.readonly = readonly

    // For readonly mode: use Milkdown to render but make it completely non-editable
    if (readonly) {
      this.createReadonlyMilkdownEditor(initialContent)
      return
    }

    // Initialize collaboration manager with initial state
    this.collaborationManager = new CollaborationManager()
    this.collaborationManager.initialize(initialYjsState)

    // Track if we have pending changes
    this.hasPendingChanges = false

    // Set up callback for local updates to send to server
    this.collaborationManager.onLocalUpdate((updateBase64, userId) => {
      // Only push if LiveView is connected
      if (!this.el.isConnected) return

      // Extract markdown content and complete state
      const markdown = this.getMarkdownContent()
      const completeState = this.collaborationManager.getCompleteState()

      // IMMEDIATELY send update to server with complete state
      // Server will handle debouncing to prevent race conditions
      this.pushEvent('yjs_update', {
        update: updateBase64,
        complete_state: completeState,
        user_id: userId,
        markdown: markdown
      })

      this.hasPendingChanges = true
    })

    // Set up callback for awareness updates
    this.collaborationManager.onAwarenessUpdate((updateBase64, userId) => {
      // Only push if LiveView is connected
      if (!this.el.isConnected) return

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

    // Handle page visibility changes (tab switching, minimizing)
    this.visibilityHandler = () => {
      if (document.hidden && this.hasPendingChanges) {
        this.forceSave()
      }
    }
    document.addEventListener('visibilitychange', this.visibilityHandler)

    // Handle page unload (closing tab/window, navigation)
    this.beforeUnloadHandler = () => {
      if (this.hasPendingChanges) {
        this.forceSave()
      }
    }
    window.addEventListener('beforeunload', this.beforeUnloadHandler)

    // Periodic backup save (every 30 seconds)
    this.backupSaveInterval = setInterval(() => {
      if (this.hasPendingChanges) {
        this.forceSave()
      }
    }, 30000)

    // Create Milkdown editor WITHOUT history/keymap (we'll add them later as raw plugins)
    const editor = Editor.make()
      .config((ctx) => {
        ctx.set(rootCtx, this.el)
      })
      .use(nord)
      .use(commonmark)
      .use(gfm)
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

        // Add click handler for task list checkboxes
        this.setupTaskListClickHandler(view)
      })
    }).catch((error) => {
      console.error('Failed to create Milkdown editor:', error)
    })
  },

  createReadonlyMilkdownEditor(initialContent) {
    // Create a Milkdown editor that's completely read-only
    const editor = Editor.make()
      .config((ctx) => {
        ctx.set(rootCtx, this.el)
        ctx.set(defaultValueCtx, initialContent || '')
      })
      .use(nord)
      .use(commonmark)
      .use(gfm)

    this.editor = editor

    editor.create().then(() => {
      this.editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)

        // Make editor completely non-editable with aggressive blocking
        view.setProps({
          editable: () => false,
          attributes: {
            contenteditable: 'false',
            style: 'cursor: default; user-select: text;'
          },
          handleDOMEvents: {
            // Block ALL input events
            beforeinput: () => true,
            input: () => true,
            keydown: () => true,
            keypress: () => true,
            keyup: () => true,
            paste: () => true,
            cut: () => true,
            copy: () => false, // Allow copy
            drop: () => true,
            dragstart: () => true,
            dragover: () => true,
            compositionstart: () => true,
            compositionupdate: () => true,
            compositionend: () => true,
          }
        })

        // Force contenteditable to false on DOM
        if (view.dom) {
          view.dom.contentEditable = 'false'
          view.dom.style.cursor = 'default'
          view.dom.style.userSelect = 'text'

          // Add a mutation observer to ensure contenteditable stays false
          const observer = new MutationObserver((mutations) => {
            if (view.dom.contentEditable !== 'false') {
              view.dom.contentEditable = 'false'
            }
          })
          observer.observe(view.dom, { attributes: true, attributeFilter: ['contenteditable'] })
          this.readonlyObserver = observer
        }
      })
    }).catch((error) => {
      console.error('Failed to create readonly Milkdown editor:', error)
    })
  },

  setupTaskListClickHandler(view) {
    // Add click handler to toggle task list checkboxes
    const clickHandler = (event) => {
      // Only handle clicks on the checkbox area (::before pseudo-element area)
      const taskItem = event.target.closest('li[data-item-type="task"]')
      if (!taskItem) return

      // Check if click was on the checkbox area (left 2rem padding)
      const rect = taskItem.getBoundingClientRect()
      const clickX = event.clientX - rect.left

      // Only process clicks in the checkbox area (first 2rem)
      if (clickX > 32) return // 2rem = 32px typically

      try {
        // Get the position of the clicked element in the document
        const pos = view.posAtDOM(taskItem, 0)
        if (pos == null) return

        const { state } = view
        const { doc } = state
        const $pos = doc.resolve(pos)

        // Find the list item node
        let listItemNode = null
        let listItemPos = null

        for (let depth = $pos.depth; depth > 0; depth--) {
          const node = $pos.node(depth)
          if (node.type.name === 'task_list_item' || node.type.name === 'list_item') {
            listItemNode = node
            listItemPos = $pos.before(depth)
            break
          }
        }

        if (!listItemNode || listItemNode.attrs.checked === undefined) return

        // Toggle the checked attribute
        const currentChecked = listItemNode.attrs.checked
        const newAttrs = { ...listItemNode.attrs, checked: !currentChecked }

        // Create a transaction to update the node without changing selection
        const tr = state.tr.setNodeMarkup(listItemPos, null, newAttrs)

        // Dispatch without scrolling into view
        view.dispatch(tr)

        // Prevent default to avoid selection changes
        event.preventDefault()
        event.stopPropagation()
      } catch (error) {
        console.error('Error toggling task list item:', error)
      }
    }

    // Store the handler so we can remove it later
    this.taskListClickHandler = clickHandler
    view.dom.addEventListener('click', clickHandler)
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

  forceSave() {
    // Skip if readonly or no pending changes or no collaboration manager
    if (this.readonly || !this.collaborationManager || !this.hasPendingChanges) {
      return
    }

    try {
      const markdown = this.getMarkdownContent()
      const completeState = this.collaborationManager.getCompleteState()

      // Use sendBeacon for reliable delivery during page unload
      // Falls back to pushEvent if sendBeacon is not available
      const data = {
        complete_state: completeState,
        markdown: markdown
      }

      // Try to use sendBeacon for more reliable delivery during unload
      if (navigator.sendBeacon) {
        // Note: sendBeacon doesn't work with LiveView events
        // So we still use pushEvent, but mark it as high priority
        this.pushEvent('force_save', data)
      } else {
        this.pushEvent('force_save', data)
      }

      this.hasPendingChanges = false
    } catch (error) {
      console.error('Error forcing save:', error)
    }
  },

  destroyed() {
    // Force save any pending changes before cleanup
    if (this.hasPendingChanges) {
      this.forceSave()
    }

    // Clear periodic backup interval
    if (this.backupSaveInterval) {
      clearInterval(this.backupSaveInterval)
      this.backupSaveInterval = null
    }

    // Remove event listeners
    if (this.visibilityHandler) {
      document.removeEventListener('visibilitychange', this.visibilityHandler)
    }
    if (this.beforeUnloadHandler) {
      window.removeEventListener('beforeunload', this.beforeUnloadHandler)
    }

    // Disconnect readonly observer
    if (this.readonlyObserver) {
      this.readonlyObserver.disconnect()
      this.readonlyObserver = null
    }

    // Remove task list click handler
    if (this.taskListClickHandler) {
      this.editor?.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        if (view?.dom) {
          view.dom.removeEventListener('click', this.taskListClickHandler)
        }
      })
      this.taskListClickHandler = null
    }

    if (this.collaborationManager) {
      this.collaborationManager.destroy()
    }
    if (this.editor) {
      this.editor.destroy()
    }
  }
}

import { ChatPanel, ChatMessages, ChatInput } from './chat_hooks'

/**
 * AutoHideFlash Hook
 *
 * Automatically hides flash messages after 1 second
 */
export const AutoHideFlash = {
  mounted() {
    // Auto-hide after 1 second (1000ms)
    this.timeout = setTimeout(() => {
      // Trigger the phx-click event to hide the flash
      this.el.click()
    }, 1000)
  },

  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

export default {
  MilkdownEditor,
  ChatPanel,
  ChatMessages,
  ChatInput,
  AutoHideFlash
}
