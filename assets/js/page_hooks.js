import { Editor, rootCtx, editorViewCtx, defaultValueCtx, serializerCtx, parserCtx } from '@milkdown/core'
import { commonmark } from '@milkdown/preset-commonmark'
import { gfm } from '@milkdown/preset-gfm'
import { nord } from '@milkdown/theme-nord'
import { clipboard } from '@milkdown/plugin-clipboard'
import { CollaborationManager } from './collaboration'
import { aiResponseNode } from './ai-response-node'
import { AIAssistantManager } from './ai-integration'
import { remarkBreaksPlugin } from './remark-breaks-plugin'

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
    const userName = this.el.dataset.userName || ''

    this.readonly = readonly

    // For readonly mode: use Milkdown to render but make it completely non-editable
    if (readonly) {
      this.createReadonlyMilkdownEditor(initialContent)
      return
    }

    // Initialize collaboration manager with initial state
    this.collaborationManager = new CollaborationManager({ userName })
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

    // Listen for insert-text events from chat panel
    this.handleEvent('insert-text', ({ content }) => {
      this.insertTextIntoEditor(content)
    })

    // Listen for AI streaming events
    this.handleEvent('ai_chunk', (data) => {
      if (this.aiAssistant) {
        this.aiAssistant.handleAIChunk(data)
      }
    })

    this.handleEvent('ai_done', (data) => {
      if (this.aiAssistant) {
        this.aiAssistant.handleAIDone(data)
      }
    })

    this.handleEvent('ai_error', (data) => {
      if (this.aiAssistant) {
        this.aiAssistant.handleAIError(data)
      }
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
      .use(remarkBreaksPlugin)
      .use(clipboard)
      .use(aiResponseNode)

    this.editor = editor

    // Create the editor and configure collaboration
    editor.create().then(() => {
      this.editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        const parser = ctx.get(parserCtx)
        const state = view.state

        // Initialize AI Assistant Manager BEFORE configuring plugins
        this.aiAssistant = new AIAssistantManager({
          view,
          schema: state.schema,
          parser,
          pushEvent: this.pushEvent.bind(this)
        })

        // Create AI mention plugin
        const aiPlugin = this.aiAssistant.createPlugin()

        // Configure ProseMirror with collaboration + undo/redo + AI plugins
        // IMPORTANT: AI plugin is added FIRST so it can handle Enter key before other plugins
        const newState = this.collaborationManager.configureProseMirrorPlugins(view, state, [aiPlugin])
        view.updateState(newState)

        // Add click handler for task list checkboxes
        this.setupTaskListClickHandler(view)

        // Add click handler to focus editor when clicking on empty space
        this.setupClickToFocus(view)

        // Set up staleness detection on editor focus
        this.setupStalenessDetection(view)
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
      .use(remarkBreaksPlugin)

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

  setupClickToFocus(view) {
    // Add click handler to the editor container to focus editor when clicking on empty space
    const clickToFocusHandler = (event) => {
      // Check if click is on the editor container or its wrapper/empty areas
      // Don't focus if clicking on interactive elements or actual content
      const target = event.target

      // If clicking directly on the container
      if (target === this.el) {
        this.focusEditorAtEnd(view)
        event.preventDefault()
        return
      }

      // If clicking on the prosemirror editor wrapper or empty space within it
      // Check if the target has the milkdown/prosemirror classes or is relatively empty
      if (target.classList.contains('milkdown') ||
          target.classList.contains('ProseMirror') ||
          target.classList.contains('editor') ||
          target === view.dom ||
          // Allow clicking on paragraph/div containers if they're mostly empty
          (target.closest('.ProseMirror') &&
           ['P', 'DIV', 'SECTION', 'ARTICLE'].includes(target.tagName) &&
           target.textContent.trim().length === 0)) {
        this.focusEditorAtEnd(view)
        event.preventDefault()
        return
      }
    }

    // Store the handler so we can remove it later
    this.clickToFocusHandler = clickToFocusHandler
    this.el.addEventListener('click', clickToFocusHandler)
  },

  focusEditorAtEnd(view) {
    // Focus the editor at the end of the document
    const { state } = view
    const endPos = state.doc.content.size
    const tr = state.tr.setSelection(
      state.constructor.Selection.near(state.doc.resolve(endPos))
    )
    view.dispatch(tr)
    view.focus()
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

  setupStalenessDetection(view) {
    // Check for stale state on editor focus (e.g., switching tabs)
    // The improved staleness detection will handle false positives by only
    // warning when DB has content we're missing (not when client is ahead)
    const focusHandler = () => {
      this.checkForStaleness()
    }

    // Store handler for cleanup
    this.stalenessCheckHandler = focusHandler
    view.dom.addEventListener('focus', focusHandler)

    // Also check when LiveView reconnects
    this.handleEvent('phx:connected', () => {
      this.checkForStaleness()
    })
  },

  async checkForStaleness() {
    if (!this.collaborationManager || this.readonly) {
      return
    }

    try {
      await this.collaborationManager.checkForStaleness(
        this.pushEvent.bind(this),
        (freshDbState) => {
          this.showStaleStateModal(freshDbState)
        }
      )
    } catch (error) {
      console.error('Error checking for staleness:', error)
    }
  },

  showStaleStateModal(freshDbState) {
    const hasLocalChanges = this.hasPendingChanges
    const message = this._buildSyncMessage(hasLocalChanges)

    if (confirm(message)) {
      this._performSync(freshDbState, hasLocalChanges)
      this.hasPendingChanges = false
    }
  },

  _buildSyncMessage(hasLocalChanges) {
    let message = 'This page has been edited elsewhere.\n\n'

    if (hasLocalChanges) {
      message += 'You have unsaved local changes. Click OK to:\n' +
                 '1. Save your local changes\n' +
                 '2. Merge them with the latest version\n\n' +
                 'Your changes will NOT be lost - they will be combined with the latest edits.\n\n' +
                 'Click Cancel to continue editing without syncing.'
    } else {
      message += 'Click OK to load the latest version.\n' +
                 'Click Cancel to continue viewing the current version.'
    }

    return message
  },

  _performSync(freshDbState, hasLocalChanges) {
    if (hasLocalChanges) {
      // Save local changes first, then merge and broadcast
      this.forceSave()
      setTimeout(() => {
        this.collaborationManager.applyFreshState(freshDbState)
        setTimeout(() => this.broadcastMergedState(), 100)
      }, 100)
    } else {
      // No local changes, just merge DB state and broadcast
      this.collaborationManager.applyFreshState(freshDbState)
      setTimeout(() => this.broadcastMergedState(), 100)
    }
  },

  broadcastMergedState() {
    // After merging, send the merged state to the server
    // which will broadcast it to other clients
    const markdown = this.getMarkdownContent()
    const completeState = this.collaborationManager.getCompleteState()
    const userId = this.collaborationManager.getUserId()

    // Send as a yjs_update which will be broadcast to other clients
    this.pushEvent('yjs_update', {
      update: completeState,
      complete_state: completeState,
      user_id: userId,
      markdown: markdown
    })
  },

  insertTextIntoEditor(content) {
    // Insert text from chat into the editor at current cursor position
    if (!this.editor || !content || this.readonly) {
      return
    }

    try {
      this.editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        const parser = ctx.get(parserCtx)
        if (!view || !parser) return

        const { state } = view
        const { schema } = state
        const { selection } = state

        // Parse markdown content into ProseMirror nodes
        // The parser returns either a Node or a string (on error)
        const parsed = parser(content.trim())

        // Handle parser errors (like clipboard plugin does)
        if (!parsed || typeof parsed === 'string') {
          console.error('Error parsing markdown:', parsed)
          return
        }

        // Extract the content nodes (skip the top-level doc node)
        const nodes = []
        parsed.content.forEach(node => {
          nodes.push(node)
        })

        // Add empty paragraph for spacing
        nodes.push(schema.nodes.paragraph.create())

        // Get cursor position and parent node info
        const $pos = selection.$head
        const parent = $pos.parent

        // Check if we're in an empty paragraph
        const isEmptyParagraph = parent.type.name === 'paragraph' && parent.content.size === 0

        let insertPos
        if (isEmptyParagraph) {
          // If in empty paragraph, replace it
          const parentPos = $pos.before($pos.depth)
          const tr = state.tr.replaceWith(parentPos, parentPos + parent.nodeSize, nodes)
          view.dispatch(tr)
        } else {
          // If paragraph has content, insert after current paragraph
          insertPos = $pos.after($pos.depth)
          const tr = state.tr.insert(insertPos, nodes)
          view.dispatch(tr)
        }

        // Focus the editor
        view.focus()
      })
    } catch (error) {
      console.error('Error inserting text into editor:', error)
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

    // Remove click-to-focus handler
    if (this.clickToFocusHandler) {
      this.el.removeEventListener('click', this.clickToFocusHandler)
      this.clickToFocusHandler = null
    }

    // Remove staleness check handler
    if (this.stalenessCheckHandler) {
      this.editor?.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        if (view?.dom) {
          view.dom.removeEventListener('focus', this.stalenessCheckHandler)
        }
      })
      this.stalenessCheckHandler = null
    }

    // Cleanup AI assistant
    if (this.aiAssistant) {
      this.aiAssistant.destroy()
      this.aiAssistant = null
    }

    if (this.collaborationManager) {
      this.collaborationManager.destroy()
    }
    if (this.editor) {
      this.editor.destroy()
    }
  }
}

/**
 * PageTitleInput Hook
 *
 * Handles keyboard interactions for the page title input:
 * - Enter key: blur input (triggers autosave) and focus editor
 * - Escape key: cancel editing without saving
 */
export const PageTitleInput = {
  mounted() {
    this.handleKeyDown = (e) => {
      if (e.key === 'Enter') {
        e.preventDefault()
        // Blur to trigger autosave
        this.el.blur()
        // Focus editor after a short delay to allow blur event to process
        setTimeout(() => {
          const editor = document.querySelector('#editor-container .ProseMirror')
          if (editor) {
            editor.focus()
          }
        }, 100)
      }
    }

    this.el.addEventListener('keydown', this.handleKeyDown)
  },

  destroyed() {
    this.el.removeEventListener('keydown', this.handleKeyDown)
  }
}
