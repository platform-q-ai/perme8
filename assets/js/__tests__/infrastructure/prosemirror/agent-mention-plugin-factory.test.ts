/**
 * Tests for Agent Mention Plugin Factory
 * 
 * Tests the ProseMirror plugin that detects @j commands and sends them to backend.
 * Backend is responsible for parsing and validation - frontend just detects the pattern.
 * 
 * This is an infrastructure test - we're testing the ProseMirror adapter.
 */

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest'
import { EditorState } from '@milkdown/prose/state'
import { EditorView } from '@milkdown/prose/view'
import { Schema } from '@milkdown/prose/model'
import { TextSelection } from '@milkdown/prose/state'
import { createAgentMentionPlugin, mentionPluginKey } from '../../../infrastructure/prosemirror/agent-mention-plugin-factory'

// Create minimal schema for testing
const createTestSchema = (): Schema => {
  return new Schema({
    nodes: {
      doc: { content: 'block+' },
      paragraph: {
        content: 'text*',
        group: 'block',
        parseDOM: [{ tag: 'p' }],
        toDOM() {
          return ['p', 0]
        }
      },
      text: {
        group: 'inline'
      },
      agent_response: {
        group: 'block',
        attrs: {
          nodeId: { default: '' },
          state: { default: 'streaming' },
          content: { default: '' },
          error: { default: '' }
        },
        parseDOM: [{ tag: 'div[data-agent-response]' }],
        toDOM(node) {
          return ['div', { 'data-agent-response': node.attrs.nodeId }, node.attrs.content]
        }
      }
    }
  })
}

describe('Agent Mention Plugin - Command Detection', () => {
  let mockOnQuery: any
  let schema: Schema
  let container: HTMLElement

  beforeEach(() => {
    mockOnQuery = vi.fn()
    schema = createTestSchema()
    container = document.createElement('div')
    document.body.appendChild(container)
  })

  afterEach(() => {
    document.body.removeChild(container)
  })

  test('detects @j command pattern', () => {
    const plugin = createAgentMentionPlugin(schema, mockOnQuery)
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('@j writer What is this?')
      ])
    ])

    const state = EditorState.create({
      doc,
      plugins: [plugin]
    })

    // Set selection at end of mention
    const pos = 23
    const $pos = state.doc.resolve(pos)
    const tr = state.tr.setSelection(TextSelection.near($pos))
    const newState = state.apply(tr)

    const pluginState = mentionPluginKey.getState(newState)
    
    // Should detect active mention
    expect(pluginState?.activeMention).toBeTruthy()
    if (pluginState?.activeMention) {
      expect(pluginState.activeMention.text).toBe('@j writer What is this?')
    }
  })

  test('sends full command text to backend on Enter', () => {
    const plugin = createAgentMentionPlugin(schema, mockOnQuery)
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('@j my-agent Question here')
      ])
    ])

    const view = new EditorView(container, {
      state: EditorState.create({
        doc,
        plugins: [plugin]
      })
    })

    // Position cursor in the mention
    const pos = 20
    const $pos = view.state.doc.resolve(pos)
    const tr = view.state.tr.setSelection(TextSelection.near($pos))
    view.dispatch(tr)

    // Simulate Enter key
    const event = new KeyboardEvent('keydown', {
      key: 'Enter',
      bubbles: true,
      cancelable: true
    })
    view.dom.dispatchEvent(event)

    // Should call onQuery with full command text
    expect(mockOnQuery).toHaveBeenCalledWith(
      expect.objectContaining({
        command: '@j my-agent Question here',
        nodeId: expect.any(String)
      })
    )

    view.destroy()
  })

  test('replaces command with agent_response node', () => {
    const plugin = createAgentMentionPlugin(schema, mockOnQuery)
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('@j agent Question?')
      ])
    ])

    const view = new EditorView(container, {
      state: EditorState.create({
        doc,
        plugins: [plugin]
      })
    })

    // Position cursor in mention
    const pos = 15
    const $pos = view.state.doc.resolve(pos)
    const tr = view.state.tr.setSelection(TextSelection.near($pos))
    view.dispatch(tr)

    // Simulate Enter
    const event = new KeyboardEvent('keydown', {
      key: 'Enter',
      bubbles: true,
      cancelable: true
    })
    view.dom.dispatchEvent(event)

    // Should replace with agent_response node
    const nodes = []
    view.state.doc.descendants((node) => {
      nodes.push(node.type.name)
    })

    expect(nodes).toContain('agent_response')
    expect(view.state.doc.textContent).not.toContain('@j agent Question?')

    view.destroy()
  })

  test('does not trigger on Enter outside of @j pattern', () => {
    const plugin = createAgentMentionPlugin(schema, mockOnQuery)
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('Regular text here')
      ])
    ])

    const view = new EditorView(container, {
      state: EditorState.create({
        doc,
        plugins: [plugin]
      })
    })

    // Simulate Enter
    const event = new KeyboardEvent('keydown', {
      key: 'Enter',
      bubbles: true,
      cancelable: true
    })
    view.dom.dispatchEvent(event)

    // Should not call onQuery
    expect(mockOnQuery).not.toHaveBeenCalled()

    view.destroy()
  })
})
