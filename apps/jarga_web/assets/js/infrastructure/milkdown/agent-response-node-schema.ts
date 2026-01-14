/**
 * Agent Response Node Schema for Milkdown
 *
 * Custom ProseMirror node for displaying agent responses inline.
 * Uses the Milkdown $node API.
 */

import { $node } from '@milkdown/utils'

/**
 * Agent Response Node Schema
 *
 * This creates an inline, atomic node that displays agent responses
 * as they stream in. The node is temporary and gets replaced with
 * parsed markdown when the response completes.
 */
export const agentResponseNode = $node('agent_response', () => ({
  group: 'inline',
  inline: true,
  atom: true,

  attrs: {
    nodeId: { default: '' },
    state: { default: 'streaming' },
    content: { default: '' },
    error: { default: '' }
  },

  parseDOM: [
    {
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
    }
  ],

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
    } else if (state === 'streaming' && !content) {
      // Show loading indicator when streaming starts with no content yet
      dom.textContent = 'Agent thinking...'
      dom.className = 'text-base-content opacity-60'
      
      // Add animated dots
      const dots = document.createElement('span')
      dots.className = 'loading-dots'
      dots.textContent = ' '
      dom.appendChild(dots)
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
  parseMarkdown: {
    match: () => false,
    runner: () => {}
  },

  toMarkdown: {
    match: (node) => node.type.name === 'agent_response',
    runner: () => {
      // The agent response node is temporary - it gets replaced with parsed markdown
      // when the response completes. During serialization while streaming,
      // we just skip outputting it to avoid serialization errors.
      // The content will be properly saved once the response completes.
    }
  }
}))
