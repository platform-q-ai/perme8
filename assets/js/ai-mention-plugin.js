/**
 * AI Mention Detection Plugin
 *
 * Detects @ai mentions and triggers AI queries on Enter key.
 */

import { Plugin, PluginKey } from '@milkdown/prose/state'
import { Decoration, DecorationSet } from '@milkdown/prose/view'

const AI_MENTION_REGEX = /@ai\s+(.+)/i

export const aiMentionPluginKey = new PluginKey('ai-mention')

/**
 * Create AI Mention Plugin
 */
export function createAIMentionPlugin(options) {
  const { onAIQuery, schema } = options

  return new Plugin({
    key: aiMentionPluginKey,

    state: {
      init() {
        return {
          decorations: DecorationSet.empty,
          activeMention: null
        }
      },

      apply(tr, prevState) {
        let decorations = prevState.decorations.map(tr.mapping, tr.doc)
        let activeMention = prevState.activeMention

        if (tr.selectionSet || tr.docChanged) {
          const { $from } = tr.selection
          const mention = findAIMentionAtCursor($from)

          if (mention) {
            const decoration = Decoration.inline(
              mention.from,
              mention.to,
              { class: 'ai-mention-active' }
            )
            decorations = DecorationSet.create(tr.doc, [decoration])
            activeMention = mention
          } else {
            decorations = DecorationSet.empty
            activeMention = null
          }
        }

        return {
          decorations,
          activeMention
        }
      }
    },

    props: {
      decorations(state) {
        return this.getState(state)?.decorations
      },

      handleKeyDown(view, event) {
        if (event.key !== 'Enter') return false

        const pluginState = this.getState(view.state)
        const mention = pluginState?.activeMention

        if (!mention) return false

        const question = extractQuestion(mention.text)

        if (!question || question.trim().length === 0) return false

        event.preventDefault()

        const nodeId = generateNodeId()
        const aiNode = createAIResponseNode(schema, nodeId)
        const { from, to } = mention

        const tr = view.state.tr
        tr.delete(from, to)
        tr.insert(from, aiNode)
        view.dispatch(tr)

        if (onAIQuery) {
          onAIQuery({ question, nodeId })
        }

        return true
      }
    }
  })
}

function findAIMentionAtCursor($pos) {
  const { parent, parentOffset } = $pos

  if (parent.type.name !== 'paragraph') return null

  const text = parent.textContent
  const matches = []
  const regex = new RegExp(AI_MENTION_REGEX, 'gi')
  let match

  while ((match = regex.exec(text)) !== null) {
    matches.push({
      from: match.index,
      to: match.index + match[0].length,
      text: match[0]
    })
  }

  for (const mention of matches) {
    if (parentOffset >= mention.from && parentOffset <= mention.to) {
      const nodeStart = $pos.start()
      return {
        from: nodeStart + mention.from,
        to: nodeStart + mention.to,
        text: mention.text
      }
    }
  }

  return null
}

function extractQuestion(text) {
  const match = text.match(AI_MENTION_REGEX)
  return match ? match[1].trim() : ''
}

function createAIResponseNode(schema, nodeId) {
  const nodeType = schema.nodes.ai_response

  if (!nodeType) {
    console.error('ai_response node type not found in schema')
    return schema.nodes.paragraph.create(null, schema.text('[AI Response]'))
  }

  return nodeType.create({
    nodeId,
    state: 'streaming',
    content: '',
    error: ''
  })
}

function generateNodeId() {
  return `ai_node_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
}

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
    return false
  }

  const newAttrs = { ...nodeToUpdate.attrs, ...updates }
  const tr = state.tr.setNodeMarkup(nodePos, null, newAttrs)
  view.dispatch(tr)

  return true
}

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
