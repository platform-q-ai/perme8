/**
 * AgentMentionPluginFactory
 *
 * Factory for creating the ProseMirror mention detection plugin
 * that integrates with the agent assistant orchestrator.
 * 
 * Detects @j commands and sends the full command text to backend for parsing.
 * Backend is the single source of truth for command validation and parsing.
 */

import { Plugin, PluginKey } from '@milkdown/prose/state'
import { Decoration, DecorationSet } from '@milkdown/prose/view'
import { Schema } from '@milkdown/prose/model'
import { NodeId } from '../../domain/value-objects/node-id'

/**
 * Agent mention pattern for triggering queries
 *
 * Detects @j followed by any text (will be parsed later)
 * Example: "@j What is the weather?" or "@j agent Question?"
 *
 * Pattern breakdown:
 * - @j = Mention trigger (case-insensitive)
 * - \s+ = One or more whitespace characters
 * - (.+) = Capture group for the rest (one or more characters)
 * - /i = Case-insensitive flag
 */
const MENTION_REGEX = /@j\s+(.+)/i

export const mentionPluginKey = new PluginKey('agentMention')

/**
 * Creates the agent mention plugin
 *
 * @param schema - ProseMirror schema with agent_response node
 * @param onQuery - Callback when user triggers an agent query with full command text
 * @returns ProseMirror Plugin
 */
export function createAgentMentionPlugin(
  schema: Schema,
  onQuery: (params: { command: string; nodeId: string }) => void
): Plugin {
  return new Plugin({
    key: mentionPluginKey,

    state: {
      init() {
        return {
          decorations: DecorationSet.empty,
          activeMention: null as { from: number; to: number; text: string } | null
        }
      },

      apply(tr, prevState) {
        let decorations = prevState.decorations.map(tr.mapping, tr.doc)
        let activeMention: { from: number; to: number; text: string } | null = prevState.activeMention

        if (tr.selectionSet || tr.docChanged) {
          const { $from } = tr.selection
          const mention = findMentionAtCursor($from)

          if (mention) {
            const decoration = Decoration.inline(mention.from, mention.to, {
              class: 'mention-active'
            })
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
        const pluginState = mentionPluginKey.getState(state)
        return pluginState?.decorations
      },

      handleDOMEvents: {
        keydown(view, event) {
          if (event.key !== 'Enter') return false

          const pluginState = mentionPluginKey.getState(view.state)
          const mention = pluginState?.activeMention

          // Try to find mention at current cursor position if state doesn't have it
          const { $from } = view.state.selection
          const foundMention = findMentionAtCursor($from)

          if (!mention && !foundMention) {
            return false
          }

          // Use found mention if active mention is null
          const activeMention = mention || foundMention
          if (!activeMention) {
            return false
          }

          // Send full command text to backend for parsing
          // Backend is the single source of truth for validation
          const commandText = activeMention.text.trim()
          
          if (!commandText || commandText.length === 0) {
            return false
          }

          event.preventDefault()
          event.stopPropagation()

          const nodeId = NodeId.generate()
          const responseNode = createAgentResponseNode(schema, nodeId)
          const { from, to } = activeMention

          const tr = view.state.tr
          tr.delete(from, to)
          tr.insert(from, responseNode)
          view.dispatch(tr)

          if (onQuery) {
            onQuery({
              command: commandText,
              nodeId: nodeId.value
            })
          }

          return true
        }
      }
    }
  })
}

/**
 * Find mention at cursor position
 */
function findMentionAtCursor($pos: any): {
  from: number
  to: number
  text: string
} | null {
  const { parent, parentOffset } = $pos

  if (parent.type.name !== 'paragraph') return null

  const text = parent.textContent
  const matches: Array<{ from: number; to: number; text: string }> = []
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

/**
 * Create agent response node
 */
function createAgentResponseNode(schema: Schema, nodeId: NodeId) {
  const nodeType = schema.nodes.agent_response

  if (!nodeType) {
    console.error('agent_response node type not found in schema')
    // Fallback to paragraph
    return schema.nodes.paragraph.create(null, schema.text('[Agent Response]'))
  }

  return nodeType.create({
    nodeId: nodeId.value,
    state: 'streaming',
    content: '',
    error: ''
  })
}
