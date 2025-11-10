import { createAIMentionPlugin, updateAIResponseNode, appendChunkToNode } from './ai-mention-plugin'

/**
 * AI Assistant Manager
 *
 * Coordinates AI assistance between:
 * - Milkdown editor (ProseMirror view)
 * - AI mention plugin (detection and node creation)
 * - LiveView hook (server communication)
 *
 * Responsibilities:
 * - Configure AI mention plugin with callbacks
 * - Handle AI query requests
 * - Process streaming responses
 * - Update AI response nodes
 */
export class AIAssistantManager {
  /**
   * @param {Object} options
   * @param {Object} options.view - ProseMirror EditorView
   * @param {Object} options.schema - ProseMirror schema
   * @param {Function} options.pushEvent - LiveView pushEvent function
   */
  constructor(options) {
    console.log('[AIAssistantManager] Constructing with options:', { hasView: !!options.view, hasSchema: !!options.schema, hasPushEvent: !!options.pushEvent })

    this.view = options.view
    this.schema = options.schema
    this.pushEvent = options.pushEvent

    // Track active AI queries
    this.activeQueries = new Map() // nodeId -> { question, startTime }

    // Bind methods
    this.handleAIQuery = this.handleAIQuery.bind(this)
    this.handleAIChunk = this.handleAIChunk.bind(this)
    this.handleAIDone = this.handleAIDone.bind(this)
    this.handleAIError = this.handleAIError.bind(this)

    console.log('[AIAssistantManager] Construction complete')
  }

  /**
   * Create and return the AI mention plugin instance
   *
   * This should be called after the manager is created to get the
   * ProseMirror plugin instance.
   *
   * @returns {Plugin} - ProseMirror plugin
   */
  createPlugin() {
    return createAIMentionPlugin({
      schema: this.schema,
      onAIQuery: this.handleAIQuery
    })
  }

  /**
   * Handle AI query trigger from mention plugin
   *
   * @param {Object} params
   * @param {string} params.question - User's question
   * @param {string} params.nodeId - AI response node ID
   */
  handleAIQuery({ question, nodeId }) {
    console.log(`[AIAssistant] Query triggered: "${question}" (${nodeId})`)

    // Track query
    this.activeQueries.set(nodeId, {
      question,
      startTime: Date.now()
    })

    // Send to LiveView
    this.pushEvent('ai_query', {
      question,
      node_id: nodeId
    })
  }

  /**
   * Handle streaming chunk from server
   *
   * @param {Object} data
   * @param {string} data.node_id - Node ID
   * @param {string} data.chunk - Text chunk
   */
  handleAIChunk({ node_id, chunk }) {
    console.log(`[AIAssistant] Chunk received for ${node_id}: ${chunk.length} chars`)

    // Append chunk to node
    const success = appendChunkToNode(this.view, node_id, chunk)

    if (!success) {
      console.warn(`[AIAssistant] Failed to append chunk to node ${node_id}`)
    }
  }

  /**
   * Handle completion from server
   *
   * @param {Object} data
   * @param {string} data.node_id - Node ID
   * @param {string} data.response - Complete response text
   */
  handleAIDone({ node_id, response }) {
    console.log(`[AIAssistant] Query completed for ${node_id}`)

    // Find the AI response node and replace it with properly formatted content
    const { state } = this.view
    const { doc, schema } = state

    let nodePos = null
    let parentNode = null
    let indexInParent = null

    doc.descendants((node, pos, parent, index) => {
      if (node.type.name === 'ai_response' && node.attrs.nodeId === node_id) {
        nodePos = pos
        parentNode = parent
        indexInParent = index
        return false
      }
    })

    if (nodePos !== null && parentNode) {
      const tr = state.tr

      // Split response by line breaks and create proper paragraph nodes
      const lines = response.split('\n')

      // Calculate positions BEFORE making any changes
      const parentStart = nodePos - indexInParent - 1
      const parentEnd = parentStart + parentNode.nodeSize

      // Delete the AI response node
      tr.delete(nodePos, nodePos + 1)

      // If the AI response is inside a paragraph, insert the first line as text
      if (parentNode.type.name === 'paragraph') {
        // Insert first line as text inline at the position where we deleted
        if (lines[0]) {
          tr.insertText(lines[0], nodePos)
        }

        // Calculate where to insert remaining paragraphs (after the current paragraph)
        // After deletion and first line insertion, we need to map the parent end position
        const afterFirstLine = nodePos + (lines[0] ? lines[0].length : 0)
        const remainingInParent = parentEnd - (nodePos + 1) // Content after the AI node
        const insertAfterParent = afterFirstLine + remainingInParent

        // Insert remaining lines as new paragraphs after the current paragraph
        // Insert them with increasing positions to maintain order
        let currentInsertPos = insertAfterParent
        for (let i = 1; i < lines.length; i++) {
          const paragraphNode = schema.nodes.paragraph.create(
            null,
            lines[i] ? schema.text(lines[i]) : null
          )
          tr.insert(currentInsertPos, paragraphNode)
          currentInsertPos += paragraphNode.nodeSize
        }
      } else {
        // Not in a paragraph, insert all lines as paragraphs at the deletion point
        let currentPos = nodePos
        lines.forEach((line) => {
          const paragraphNode = schema.nodes.paragraph.create(
            null,
            line ? schema.text(line) : null
          )
          tr.insert(currentPos, paragraphNode)
          currentPos += paragraphNode.nodeSize
        })
      }

      this.view.dispatch(tr)

      // Log completion time
      const query = this.activeQueries.get(node_id)
      if (query) {
        const duration = Date.now() - query.startTime
        console.log(`[AIAssistant] Query took ${duration}ms`)
        this.activeQueries.delete(node_id)
      }
    } else {
      console.warn(`[AIAssistant] Failed to find node ${node_id}`)
    }
  }

  /**
   * Handle error from server
   *
   * @param {Object} data
   * @param {string} data.node_id - Node ID
   * @param {string} data.error - Error message
   */
  handleAIError({ node_id, error }) {
    console.error(`[AIAssistant] Error for ${node_id}: ${error}`)

    // Update node to error state
    const success = updateAIResponseNode(this.view, node_id, {
      state: 'error',
      error: error || 'An unknown error occurred',
      content: '' // Clear content on error
    })

    if (success) {
      // Remove from active queries
      this.activeQueries.delete(node_id)
    } else {
      console.warn(`[AIAssistant] Failed to update node ${node_id} to error state`)
    }
  }

  /**
   * Get statistics about active queries
   *
   * @returns {Object} - { count, queries }
   */
  getActiveQueriesInfo() {
    return {
      count: this.activeQueries.size,
      queries: Array.from(this.activeQueries.entries()).map(([nodeId, query]) => ({
        nodeId,
        question: query.question,
        duration: Date.now() - query.startTime
      }))
    }
  }

  /**
   * Cancel an active query
   *
   * @param {string} nodeId - Node ID to cancel
   */
  cancelQuery(nodeId) {
    const query = this.activeQueries.get(nodeId)

    if (query) {
      console.log(`[AIAssistant] Cancelling query ${nodeId}`)

      // Update node to error state (cancelled)
      updateAIResponseNode(this.view, nodeId, {
        state: 'error',
        error: 'Query cancelled by user',
        content: ''
      })

      // Remove from active queries
      this.activeQueries.delete(nodeId)

      // TODO: Send cancellation to server if backend supports it
      // this.pushEvent('ai_cancel', { node_id: nodeId })
    }
  }

  /**
   * Cancel all active queries
   */
  cancelAllQueries() {
    const nodeIds = Array.from(this.activeQueries.keys())

    console.log(`[AIAssistant] Cancelling ${nodeIds.length} active queries`)

    nodeIds.forEach(nodeId => {
      this.cancelQuery(nodeId)
    })
  }

  /**
   * Cleanup
   */
  destroy() {
    console.log('[AIAssistant] Destroying manager')

    // Cancel all active queries
    this.cancelAllQueries()

    // Clear references
    this.view = null
    this.schema = null
    this.pushEvent = null
    this.activeQueries.clear()
  }
}
