import * as Y from 'yjs'
import { ySyncPlugin, yUndoPlugin, ySyncPluginKey, undo, redo } from 'y-prosemirror'
import { keymap } from 'prosemirror-keymap'
import { Plugin } from '@milkdown/prose/state'
import { Awareness, encodeAwarenessUpdate, applyAwarenessUpdate } from 'y-protocols/awareness'
import { createAwarenessPlugin } from './awareness-plugin'

/**
 * CollaborationManager handles all Yjs collaboration logic.
 *
 * Responsibilities:
 * - Manages Yjs document lifecycle
 * - Handles local and remote updates
 * - Configures ProseMirror plugins for collaboration
 * - Manages per-client undo/redo via Y.UndoManager
 * - Manages awareness for cursor and selection tracking
 *
 * @class CollaborationManager
 */
export class CollaborationManager {
  constructor(config = {}) {
    this.userId = this._generateUserId()
    this.userName = config.userName || `User ${this.userId.substring(5, 9)}`
    this.ydoc = null
    this.yXmlFragment = null
    this.awareness = null
    this.onLocalUpdateCallback = null
    this.onAwarenessUpdateCallback = null
    this.yjsUndoManager = null
    this.editorView = null

    // Configuration
    this.config = {
      captureTimeout: config.captureTimeout || 500,
      ...config
    }
  }

  /**
   * Initialize the collaboration manager with a Yjs document.
   * @param {string} initialStateBase64 - Optional Base64 encoded initial Yjs state
   * @returns {void}
   */
  initialize(initialStateBase64 = null) {
    this.ydoc = new Y.Doc()

    // Apply initial state if provided
    if (initialStateBase64 && initialStateBase64.length > 0) {
      try {
        const stateArray = Uint8Array.from(atob(initialStateBase64), c => c.charCodeAt(0))
        Y.applyUpdate(this.ydoc, stateArray)
      } catch (error) {
        console.error('Error applying initial Yjs state:', error)
      }
    }

    this.yXmlFragment = this.ydoc.get('prosemirror', Y.XmlFragment)

    // Create awareness instance
    this.awareness = new Awareness(this.ydoc)

    // Set local awareness state
    this.awareness.setLocalState({
      userId: this.userId,
      userName: this.userName,
      selection: null
    })

    // Listen for local Yjs updates
    this.ydoc.on('update', this._handleYjsUpdate.bind(this))

    // Listen for awareness changes
    this.awareness.on('change', this._handleAwarenessChange.bind(this))
  }

  /**
   * Configure ProseMirror editor with collaboration plugins.
   *
   * Strategy:
   * - Apply ySyncPlugin for Yjs collaboration
   * - Apply awareness plugin for cursor/selection tracking
   * - Apply history and keymap plugins AFTER ySyncPlugin so they can filter properly
   *
   * @param {EditorView} view - ProseMirror editor view
   * @param {EditorState} state - ProseMirror editor state
   * @returns {EditorState} New editor state with collaboration plugins
   */
  configureProseMirrorPlugins(view, state) {
    if (!this.ydoc || !this.yXmlFragment || !this.awareness) {
      throw new Error('CollaborationManager not initialized. Call initialize() first.')
    }

    // Store editor view for later use
    this.editorView = view

    // Step 1: Apply ySyncPlugin for collaboration
    const ySync = ySyncPlugin(this.yXmlFragment)
    let newState = state.reconfigure({
      plugins: [...state.plugins, ySync]
    })
    view.updateState(newState)

    // Step 2: Get the binding from ySyncPlugin
    const ySyncState = ySyncPluginKey.getState(view.state)
    const binding = ySyncState?.binding

    if (!binding) {
      throw new Error('No binding found after adding ySyncPlugin')
    }

    // Step 3: Create UndoManager that tracks only this binding's changes
    // The binding object is used as the origin for local edits
    // Remote changes use a different origin and won't be tracked
    const undoManager = new Y.UndoManager(this.yXmlFragment, {
      trackedOrigins: new Set([binding])
    })

    // Step 4: Attach UndoManager to binding so yUndoPlugin can use it
    binding.undoManager = undoManager
    this.yjsUndoManager = undoManager

    // Step 5: Add yUndoPlugin for undo/redo state management
    const yUndo = yUndoPlugin()

    // Step 6: Add keyboard shortcuts for undo/redo
    const undoRedoKeymap = keymap({
      'Mod-z': undo,
      'Mod-y': redo,
      'Mod-Shift-z': redo
    })

    // Step 7: Add awareness plugin for cursor/selection tracking
    const awarenessPlugin = createAwarenessPlugin(this.awareness, this.userId)

    // Step 8: Add selection tracking plugin
    const selectionPlugin = this._createSelectionPlugin()

    // Step 9: Apply all plugins
    newState = view.state.reconfigure({
      plugins: [...view.state.plugins, yUndo, undoRedoKeymap, awarenessPlugin, selectionPlugin]
    })

    return newState
  }

  /**
   * Apply a remote Yjs update received from the server.
   *
   * @param {string} updateBase64 - Base64 encoded Yjs update
   * @returns {void}
   */
  applyRemoteUpdate(updateBase64) {
    try {
      const updateArray = Uint8Array.from(atob(updateBase64), c => c.charCodeAt(0))
      Y.applyUpdate(this.ydoc, updateArray, 'remote')
    } catch (error) {
      console.error('Error applying remote Yjs update:', error)
      throw error
    }
  }

  /**
   * Set callback for when local updates occur.
   *
   * @param {Function} callback - Callback function that receives (updateBase64, userId)
   * @returns {void}
   */
  onLocalUpdate(callback) {
    this.onLocalUpdateCallback = callback
  }

  /**
   * Set callback for when awareness updates occur.
   *
   * @param {Function} callback - Callback function that receives (awarenessUpdate, userId)
   * @returns {void}
   */
  onAwarenessUpdate(callback) {
    this.onAwarenessUpdateCallback = callback
  }

  /**
   * Apply remote awareness update.
   *
   * @param {string} updateBase64 - Base64 encoded awareness update
   * @returns {void}
   */
  applyRemoteAwarenessUpdate(updateBase64) {
    try {
      const updateArray = Uint8Array.from(atob(updateBase64), c => c.charCodeAt(0))
      applyAwarenessUpdate(this.awareness, updateArray, 'remote')
    } catch (error) {
      console.error('Error applying remote awareness update:', error)
      throw error
    }
  }

  /**
   * Get the user ID for this client.
   *
   * @returns {string} User ID
   */
  getUserId() {
    return this.userId
  }

  /**
   * Get the Yjs document.
   *
   * @returns {Y.Doc} Yjs document
   */
  getYDoc() {
    return this.ydoc
  }

  /**
   * Get the complete document state as base64.
   *
   * @returns {string} Base64 encoded complete document state
   */
  getCompleteState() {
    if (!this.ydoc) {
      return ''
    }
    const state = Y.encodeStateAsUpdate(this.ydoc)
    return btoa(String.fromCharCode(...state))
  }

  /**
   * Check if the client's Yjs state is behind the database state.
   *
   * @param {Function} pushEventFn - Phoenix LiveView pushEvent function
   * @param {Function} onStaleCallback - Callback when stale state detected
   * @returns {Promise<boolean>} True if client is stale
   */
  async checkForStaleness(pushEventFn, onStaleCallback) {
    if (!this.ydoc) {
      return false
    }

    // Request current DB state from server
    return new Promise((resolve) => {
      pushEventFn('get_current_yjs_state', {}, (reply) => {
        try {
          const dbYjsStateBase64 = reply.yjs_state

          // Check if we're behind
          const isStale = this._isStateBehind(dbYjsStateBase64)

          if (isStale && onStaleCallback) {
            // Pass the fresh DB state to the callback
            onStaleCallback(dbYjsStateBase64)
          }

          resolve(isStale)
        } catch (error) {
          console.error('Error checking staleness:', error)
          resolve(false)
        }
      })
    })
  }

  /**
   * Check if client state is behind DB state using Yjs state vectors.
   *
   * Strategy: Test if applying DB state would change client content.
   * Only warn if DB has content client is MISSING (not if client is ahead).
   *
   * @private
   * @param {string} dbYjsStateBase64 - Base64 encoded DB yjs_state
   * @returns {boolean} True if client is missing updates from DB
   */
  _isStateBehind(dbYjsStateBase64) {
    if (!this.ydoc || !dbYjsStateBase64 || dbYjsStateBase64.length === 0) {
      return false
    }

    try {
      // Decode DB state
      const dbYjsState = Uint8Array.from(atob(dbYjsStateBase64), c => c.charCodeAt(0))

      // Get my current state and content
      const myState = Y.encodeStateAsUpdate(this.ydoc)
      const myContent = this.ydoc.get('prosemirror', Y.XmlFragment)
      const myXml = myContent.toString()

      // Quick check: if states are byte-identical, definitely in sync
      if (dbYjsState.length === myState.length) {
        let identical = true
        for (let i = 0; i < dbYjsState.length; i++) {
          if (dbYjsState[i] !== myState[i]) {
            identical = false
            break
          }
        }
        if (identical) {
          return false
        }
      }

      // Test: What would happen if we applied DB state to our current doc?
      // Create a temp doc with our current state, then apply DB state
      const testDoc = new Y.Doc()
      Y.applyUpdate(testDoc, myState)
      Y.applyUpdate(testDoc, dbYjsState)

      // Get content after applying DB state
      const testContent = testDoc.get('prosemirror', Y.XmlFragment)
      const testXml = testContent.toString()

      // If content changed after applying DB state, then DB has updates we're missing
      const dbHasNewContent = testXml !== myXml

      // Clean up temp docs
      testDoc.destroy()

      // Only warn if DB has content we're missing
      return dbHasNewContent
    } catch (error) {
      console.error('Error comparing state vectors:', error)
      return false
    }
  }

  /**
   * Merge fresh state from the database with current local state.
   *
   * This uses Yjs CRDT merge semantics - local changes are NOT lost.
   * Yjs automatically merges the states, preserving both local and remote edits.
   *
   * @param {string} freshYjsStateBase64 - Base64 encoded fresh yjs_state from DB
   * @returns {void}
   */
  applyFreshState(freshYjsStateBase64) {
    if (!this.ydoc || !freshYjsStateBase64 || freshYjsStateBase64.length === 0) {
      return
    }

    try {
      const freshYjsState = Uint8Array.from(atob(freshYjsStateBase64), c => c.charCodeAt(0))

      // MERGE fresh state with current doc using Yjs CRDT algorithm
      // This preserves both local and remote changes - nothing is lost!
      // Using 'remote' origin prevents this from being sent back to server
      Y.applyUpdate(this.ydoc, freshYjsState, 'remote')

      // Editor will automatically re-render via ySyncPlugin
    } catch (error) {
      console.error('Error applying fresh state:', error)
      throw error
    }
  }

  /**
   * Clean up resources.
   *
   * @returns {void}
   */
  destroy() {
    if (this.yjsUndoManager) {
      this.yjsUndoManager.destroy()
      this.yjsUndoManager = null
    }
    if (this.awareness) {
      this.awareness.destroy()
      this.awareness = null
    }
    if (this.ydoc) {
      this.ydoc.destroy()
      this.ydoc = null
    }
    this.yXmlFragment = null
    this.editorView = null
    this.onLocalUpdateCallback = null
    this.onAwarenessUpdateCallback = null
  }

  /**
   * Handle Yjs update events.
   *
   * @private
   * @param {Uint8Array} update - Yjs update
   * @param {any} origin - Origin of the update
   * @returns {void}
   */
  _handleYjsUpdate(update, origin) {
    // Only send local updates (not remote ones) to the server
    if (origin !== 'remote' && this.onLocalUpdateCallback) {
      const updateBase64 = btoa(String.fromCharCode(...update))
      this.onLocalUpdateCallback(updateBase64, this.userId)
    }
  }

  /**
   * Handle awareness changes.
   *
   * @private
   * @param {Object} changes - Awareness change event
   * @returns {void}
   */
  _handleAwarenessChange(changes) {
    // Notify ProseMirror that awareness changed
    if (this.editorView) {
      const tr = this.editorView.state.tr
      tr.setMeta('awarenessChanged', true)
      this.editorView.dispatch(tr)
    }

    // Send awareness updates to server
    if (this.onAwarenessUpdateCallback) {
      const update = encodeAwarenessUpdate(this.awareness, Array.from(changes.added).concat(Array.from(changes.updated)))
      const updateBase64 = btoa(String.fromCharCode(...update))
      this.onAwarenessUpdateCallback(updateBase64, this.userId)
    }
  }

  /**
   * Create a plugin to track local selection changes.
   *
   * @private
   * @returns {Plugin} ProseMirror plugin
   */
  _createSelectionPlugin() {
    return new Plugin({
      view: () => ({
        update: (view) => {
          const { state } = view
          const { selection } = state

          // Update local awareness state with selection
          this.awareness.setLocalStateField('selection', {
            anchor: selection.anchor,
            head: selection.head
          })
        }
      })
    })
  }

  /**
   * Generate a unique user ID for this client.
   *
   * @private
   * @returns {string} User ID
   */
  _generateUserId() {
    return 'user_' + Math.random().toString(36).substr(2, 9) + Date.now().toString(36)
  }
}
