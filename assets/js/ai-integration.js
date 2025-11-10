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
   * @param {Function} options.parser - Milkdown markdown parser
   * @param {Function} options.pushEvent - LiveView pushEvent function
   */
  constructor(options) {
    this.view = options.view
    this.schema = options.schema
    this.parser = options.parser
    this.pushEvent = options.pushEvent

    // Track active AI queries
    this.activeQueries = new Map() // nodeId -> { question, startTime }

    // Bind methods
    this.handleAIQuery = this.handleAIQuery.bind(this)
    this.handleAIChunk = this.handleAIChunk.bind(this)
    this.handleAIDone = this.handleAIDone.bind(this)
    this.handleAIError = this.handleAIError.bind(this)
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
    // Append chunk to node
    appendChunkToNode(this.view, node_id, chunk)
  }

  /**
   * Handle completion from server
   *
   * @param {Object} data
   * @param {string} data.node_id - Node ID
   * @param {string} data.response - Complete response text
   */
  handleAIDone({ node_id, response }) {
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

      // Parse markdown response into ProseMirror nodes
      // The parser returns either a Node or a string (on error)
      const parsed = this.parser(response.trim())

      // Handle parser errors
      if (!parsed || typeof parsed === 'string') {
        console.error('[AIAssistant] Failed to parse markdown:', parsed)
        return
      }

      // Extract the content nodes (skip the top-level doc node)
      const nodes = []
      parsed.content.forEach(node => {
        nodes.push(node)
      })

      // Calculate positions BEFORE making any changes
      const parentStart = nodePos - indexInParent - 1

      // If the AI response is inside a paragraph, we need to handle inline vs block content
      if (parentNode.type.name === 'paragraph') {
        // Check if we have any block-level nodes (paragraphs, headings, lists, etc.)
        const hasBlockNodes = nodes.some(node => !node.isInline && node.type.name !== 'text')

        if (!hasBlockNodes && nodes.length === 1 && nodes[0].type.name === 'paragraph') {
          // Single paragraph - delete AI node and insert its content inline
          const inlineContent = nodes[0].content
          tr.delete(nodePos, nodePos + 1)
          tr.insert(nodePos, inlineContent)
        } else if (hasBlockNodes) {
          // Has block nodes - split the paragraph at the AI node position
          // and insert the block nodes at the split point

          // Split the paragraph at the AI node position
          const beforeContent = parentNode.content.cut(0, indexInParent)
          const afterContent = parentNode.content.cut(indexInParent + 1)

          // Delete the entire parent paragraph
          tr.delete(parentStart, parentStart + parentNode.nodeSize)

          let currentPos = parentStart

          // Insert before-content as a paragraph if it exists
          if (beforeContent.size > 0) {
            const beforePara = schema.nodes.paragraph.create(null, beforeContent)
            tr.insert(currentPos, beforePara)
            currentPos += beforePara.nodeSize
          }

          // Insert all block nodes at the current position
          nodes.forEach((node) => {
            tr.insert(currentPos, node)
            currentPos += node.nodeSize
          })

          // Insert after-content as a paragraph if it exists
          if (afterContent.size > 0) {
            const afterPara = schema.nodes.paragraph.create(null, afterContent)
            tr.insert(currentPos, afterPara)
          }
        } else {
          // Multiple inline nodes or single non-paragraph node
          tr.delete(nodePos, nodePos + 1)
          let currentPos = nodePos
          nodes.forEach((node) => {
            tr.insert(currentPos, node)
            currentPos += node.nodeSize
          })
        }
      } else {
        // Not in a paragraph, delete AI node and insert all parsed nodes at the deletion point
        tr.delete(nodePos, nodePos + 1)
        let currentPos = nodePos
        nodes.forEach((node) => {
          tr.insert(currentPos, node)
          currentPos += node.nodeSize
        })
      }

      this.view.dispatch(tr)

      // Clean up completed query
      this.activeQueries.delete(node_id)
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
    // Update node to error state
    const success = updateAIResponseNode(this.view, node_id, {
      state: 'error',
      error: error || 'An unknown error occurred',
      content: '' // Clear content on error
    })

    if (success) {
      // Remove from active queries
      this.activeQueries.delete(node_id)
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
      // Update node to error state (cancelled)
      updateAIResponseNode(this.view, nodeId, {
        state: 'error',
        error: 'Query cancelled by user',
        content: ''
      })

      // Remove from active queries
      this.activeQueries.delete(nodeId)

      // Send cancellation to server
      this.pushEvent('ai_cancel', { node_id: nodeId })
    }
  }

  /**
   * Cancel all active queries
   */
  cancelAllQueries() {
    const nodeIds = Array.from(this.activeQueries.keys())

    nodeIds.forEach(nodeId => {
      this.cancelQuery(nodeId)
    })
  }

  /**
   * Cleanup
   */
  destroy() {
    // Cancel all active queries
    this.cancelAllQueries()

    // Clear references
    this.view = null
    this.schema = null
    this.parser = null
    this.pushEvent = null
    this.activeQueries.clear()
  }
}
