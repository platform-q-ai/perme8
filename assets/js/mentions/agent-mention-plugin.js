/**
 * Mention Detection Plugin
 *
 * Detects @j mentions and triggers agent queries on Enter key.
 */

import { Plugin, PluginKey } from '@milkdown/prose/state'
import { Decoration, DecorationSet } from '@milkdown/prose/view'
import { updateAgentResponseNode, appendChunkToAgentNode } from './mention-utils'

const MENTION_REGEX = /@j\s+(.+)/i

export const mentionPluginKey = new PluginKey('mention')

/**
 * Create Mention Plugin
 */
export function createMentionPlugin(options) {
  const { onQuery, schema } = options

  return new Plugin({
    key: mentionPluginKey,

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
          const mention = findMentionAtCursor($from)

          if (mention) {
            const decoration = Decoration.inline(
              mention.from,
              mention.to,
              { class: 'mention-active' }
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
        const responseNode = createAgentResponseNode(schema, nodeId)
        const { from, to } = mention

        const tr = view.state.tr
        tr.delete(from, to)
        tr.insert(from, responseNode)
        view.dispatch(tr)

        if (onQuery) {
          onQuery({ question, nodeId })
        }

        return true
      }
    }
  })
}

function findMentionAtCursor($pos) {
  const { parent, parentOffset } = $pos

  if (parent.type.name !== 'paragraph') return null

  const text = parent.textContent
  const matches = []
  const regex = new RegExp(MENTION_REGEX, 'gi')
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
  const match = text.match(MENTION_REGEX)
  return match ? match[1].trim() : ''
}

function createAgentResponseNode(schema, nodeId) {
  const nodeType = schema.nodes.agent_response

  if (!nodeType) {
    console.error('agent_response node type not found in schema')
    return schema.nodes.paragraph.create(null, schema.text('[Agent Response]'))
  }

  return nodeType.create({
    nodeId,
    state: 'streaming',
    content: '',
    error: ''
  })
}

function generateNodeId() {
  return `agent_node_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
}

// Re-export utilities for backwards compatibility
export { updateAgentResponseNode, appendChunkToAgentNode }
