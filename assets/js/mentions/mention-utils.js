/**
 * Mention Utilities
 *
 * Shared utilities for working with agent response nodes.
 * These functions are used by both the mention plugin and agent response node.
 */

/**
 * Find an agent response node by ID and return its position and the node itself
 */
function findAgentResponseNode(doc, nodeId) {
  let nodePos = null
  let nodeToUpdate = null

  doc.descendants((node, pos) => {
    if (node.type.name === 'agent_response' && node.attrs.nodeId === nodeId) {
      nodePos = pos
      nodeToUpdate = node
      return false
    }
  })

  return { nodePos, nodeToUpdate }
}

/**
 * Update agent response node by ID with new attribute values
 */
export function updateAgentResponseNode(view, nodeId, updates) {
  const { state } = view
  const { doc } = state

  const { nodePos, nodeToUpdate } = findAgentResponseNode(doc, nodeId)

  if (nodePos === null || !nodeToUpdate) {
    console.warn(`Agent response node not found: ${nodeId}`)
    return false
  }

  const newAttrs = { ...nodeToUpdate.attrs, ...updates }
  const tr = state.tr.setNodeMarkup(nodePos, null, newAttrs)
  view.dispatch(tr)

  return true
}

/**
 * Append a chunk of text to an agent response node's content
 */
export function appendChunkToAgentNode(view, nodeId, chunk) {
  const { state } = view
  const { doc } = state

  const { nodePos, nodeToUpdate } = findAgentResponseNode(doc, nodeId)

  if (nodePos === null || !nodeToUpdate) {
    return false
  }

  const newContent = (nodeToUpdate.attrs.content || '') + chunk
  const newAttrs = { ...nodeToUpdate.attrs, content: newContent }
  const tr = state.tr.setNodeMarkup(nodePos, null, newAttrs)
  view.dispatch(tr)

  return true
}
