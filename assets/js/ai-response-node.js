/**
 * AI Response Node for Milkdown
 *
 * This creates a custom ProseMirror node for AI responses.
 * Uses the core Milkdown plugin API.
 */

import { $ctx, $node } from '@milkdown/utils'

/**
 * AI Response Node Schema
 */
export const aiResponseNode = $node('ai_response', (ctx) => ({
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
    tag: 'span.ai-response',
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
      // Show error inline
      dom.textContent = `[AI Error: ${error || 'Unknown error'}]`
      dom.style.color = '#ef4444'
    } else {
      // Show the content as plain text
      dom.textContent = content || ''

      // Add blinking cursor if streaming and has content
      if (state === 'streaming' && content) {
        const cursor = document.createElement('span')
        cursor.className = 'ai-streaming-cursor'
        cursor.textContent = '▊'
        cursor.style.animation = 'blink 1s step-end infinite'
        cursor.style.marginLeft = '2px'
        cursor.style.color = 'inherit'
        dom.appendChild(cursor)
      }
    }

    return dom
  },

  parseMarkdown: {
    block: 'ai_response',
    getAttrs: () => ({
      nodeId: '',
      state: 'streaming',
      content: '',
      error: ''
    })
  },

  toMarkdown: {
    match: (node) => node.type.name === 'ai_response',
    runner: (state, node) => {
      state.addNode('fence', undefined, node.attrs.content || '', {
        info: 'ai-response'
      })
    }
  }
}))

/**
 * Update AI response node by ID
 */
export function updateAIResponseNode(view, nodeId, updates) {
  const { state } = view
  const { doc } = state

  let nodePos = null
  let nodeToUpdate = null

  doc.descendants((node, pos) => {
    if (node.type.name === 'ai_response' && node.attrs.nodeId === nodeId) {
      nodePos = pos
      nodeToUpdate = node
      return false
    }
  })

  if (nodePos === null || !nodeToUpdate) {
    console.warn(`AI response node not found: ${nodeId}`)
    return false
  }

  const newAttrs = { ...nodeToUpdate.attrs, ...updates }
  const tr = state.tr.setNodeMarkup(nodePos, null, newAttrs)
  view.dispatch(tr)

  return true
}

/**
 * Append chunk to AI response node
 */
export function appendChunkToNode(view, nodeId, chunk) {
  const { state } = view
  const { doc } = state

  let nodePos = null
  let nodeToUpdate = null

  doc.descendants((node, pos) => {
    if (node.type.name === 'ai_response' && node.attrs.nodeId === nodeId) {
      nodePos = pos
      nodeToUpdate = node
      return false
    }
  })

  if (nodePos === null || !nodeToUpdate) {
    return false
  }

  const newContent = (nodeToUpdate.attrs.content || '') + chunk
  const newAttrs = { ...nodeToUpdate.attrs, content: newContent }
  const tr = state.tr.setNodeMarkup(nodePos, null, newAttrs)
  view.dispatch(tr)

  return true
}
