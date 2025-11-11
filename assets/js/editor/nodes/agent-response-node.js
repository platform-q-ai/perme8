/**
 * Agent Response Node for Milkdown
 *
 * This creates a custom ProseMirror node for agent responses.
 * Uses the core Milkdown plugin API.
 */

import { $ctx, $node } from '@milkdown/utils'
import { updateAgentResponseNode, appendChunkToAgentNode } from '../../mentions/mention-utils'

/**
 * Agent Response Node Schema
 */
export const agentResponseNode = $node('agent_response', (ctx) => ({
  group: 'inline',
  inline: true,
  atom: true,

  attrs: {
    nodeId: { default: '' },
    state: { default: 'streaming' },
    content: { default: '' },
    error: { default: '' }
  },

  parseDOM: [{
    tag: 'span.agent-response',
    getAttrs: (dom) => {
      if (!(dom instanceof HTMLElement)) return false
      return {
        nodeId: dom.dataset.nodeId || '',
        state: dom.dataset.state || 'streaming',
        content: dom.dataset.content || '',
        error: dom.dataset.error || ''
      }
    }
  }],

  toDOM: (node) => {
    const { nodeId, state, content, error } = node.attrs

    // Render as an inline span to blend seamlessly with editor content
    const dom = document.createElement('span')
    dom.dataset.nodeId = nodeId
    dom.dataset.state = state

    if (state === 'error') {
      // Show error inline with DaisyUI error color
      dom.textContent = `[Agent Error: ${error || 'Unknown error'}]`
      dom.className = 'text-error'
    } else {
      // Show the content as plain text
      dom.textContent = content || ''

      // Add blinking cursor if streaming and has content
      if (state === 'streaming' && content) {
        const cursor = document.createElement('span')
        cursor.className = 'streaming-cursor'
        cursor.textContent = '▊'
        dom.appendChild(cursor)
      }
    }

    return dom
  },

  // This node is only created programmatically, never from markdown
  // But we need to provide a parseMarkdown spec that never matches
  parseMarkdown: {
    match: () => false,
    runner: () => {}
  },

  toMarkdown: {
    match: (node) => node.type.name === 'agent_response',
    runner: (state, node) => {
      // The agent response node is temporary - it gets replaced with parsed markdown
      // when the response completes. During serialization while streaming,
      // we just skip outputting it to avoid serialization errors.
      // The content will be properly saved once handleDone replaces this node.
    }
  }
}))

// Re-export utilities for backwards compatibility
export { updateAgentResponseNode, appendChunkToAgentNode }
