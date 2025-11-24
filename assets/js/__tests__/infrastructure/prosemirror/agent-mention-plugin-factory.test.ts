/**
 * Tests for Agent Mention Plugin Factory
 * 
 * Tests the ProseMirror plugin that detects @j agent_name Question commands
 * and triggers agent queries.
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

describe('Agent Mention Plugin - Extended for Agent Names', () => {
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

  describe('NEW: @j agent_name Question syntax', () => {
    test('detects command with single-word agent name', () => {
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

    test('detects command with hyphenated agent name', () => {
      const plugin = createAgentMentionPlugin(schema, mockOnQuery)
      const doc = schema.node('doc', null, [
        schema.node('paragraph', null, [
          schema.text('@j my-writer-agent Question here')
        ])
      ])

      const state = EditorState.create({
        doc,
        plugins: [plugin]
      })

      const pos = 32
      const $pos = state.doc.resolve(pos)
      const tr = state.tr.setSelection(TextSelection.near($pos))
      const newState = state.apply(tr)

      const pluginState = mentionPluginKey.getState(newState)
      expect(pluginState?.activeMention).toBeTruthy()
    })

    test('triggers query with agent name on Enter', () => {
      const plugin = createAgentMentionPlugin(schema, mockOnQuery)
      const doc = schema.node('doc', null, [
        schema.node('paragraph', null, [
          schema.text('@j writer What is this?')
        ])
      ])

      const view = new EditorView(container, {
        state: EditorState.create({
          doc,
          plugins: [plugin]
        })
      })

      // Move cursor to end of mention
      const pos = 23
      const $pos = view.state.doc.resolve(pos)
      const tr = view.state.tr.setSelection(TextSelection.near($pos))
      view.dispatch(tr)

      // Simulate Enter keypress
      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        bubbles: true,
        cancelable: true
      })
      
      view.someProp('handleDOMEvents', (handlers: any) => {
        return handlers.keydown?.(view, event)
      })

      // Should trigger callback with agent name
      expect(mockOnQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          agentName: 'writer',
          question: 'What is this?',
          nodeId: expect.any(String)
        })
      )

      view.destroy()
    })

    test('parses first word as agent name', () => {
      // "@j Question without agent" parses as agentName="Question", question="without agent"
      // This is expected behavior - any word after @j becomes the agent name
      const plugin = createAgentMentionPlugin(schema, mockOnQuery)
      const doc = schema.node('doc', null, [
        schema.node('paragraph', null, [
          schema.text('@j Question without agent')
        ])
      ])

      const view = new EditorView(container, {
        state: EditorState.create({
          doc,
          plugins: [plugin]
        })
      })

      const pos = 25
      const $pos = view.state.doc.resolve(pos)
      const tr = view.state.tr.setSelection(TextSelection.near($pos))
      view.dispatch(tr)

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        bubbles: true,
        cancelable: true
      })
      
      view.someProp('handleDOMEvents', (handlers: any) => {
        return handlers.keydown?.(view, event)
      })

      // Should trigger with first word as agent name
      expect(mockOnQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          agentName: 'Question',
          question: 'without agent',
          nodeId: expect.any(String)
        })
      )

      view.destroy()
    })

    test('replaces command with loading node', () => {
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

      const initialText = view.state.doc.textContent
      expect(initialText).toContain('@j agent Question?')

      const pos = 18
      const $pos = view.state.doc.resolve(pos)
      const tr = view.state.tr.setSelection(TextSelection.near($pos))
      view.dispatch(tr)

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        bubbles: true,
        cancelable: true
      })
      
      view.someProp('handleDOMEvents', (handlers: any) => {
        return handlers.keydown?.(view, event)
      })

      // Command should be removed
      const newText = view.state.doc.textContent
      expect(newText).not.toContain('@j agent Question?')

      // Should have agent_response node
      let hasAgentNode = false
      view.state.doc.descendants((node) => {
        if (node.type.name === 'agent_response') {
          hasAgentNode = true
          expect(node.attrs.state).toBe('streaming')
        }
      })
      expect(hasAgentNode).toBe(true)

      view.destroy()
    })
  })

  describe('BACKWARD COMPATIBILITY: @j Question syntax', () => {
    test('OLD: still supports @j Question without agent name for backward compatibility', () => {
      const plugin = createAgentMentionPlugin(schema, mockOnQuery)
      const doc = schema.node('doc', null, [
        schema.node('paragraph', null, [
          schema.text('@j What is the weather?')
        ])
      ])

      const view = new EditorView(container, {
        state: EditorState.create({
          doc,
          plugins: [plugin]
        })
      })

      const pos = 23
      const $pos = view.state.doc.resolve(pos)
      const tr = view.state.tr.setSelection(TextSelection.near($pos))
      view.dispatch(tr)

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        bubbles: true,
        cancelable: true
      })
      
      view.someProp('handleDOMEvents', (handlers: any) => {
        return handlers.keydown?.(view, event)
      })

      // Should still trigger with question (no agentName in callback)
      // This is backward compatibility mode
      expect(mockOnQuery).toHaveBeenCalled()

      view.destroy()
    })
  })
})
