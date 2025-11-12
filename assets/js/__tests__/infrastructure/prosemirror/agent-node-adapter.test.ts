/**
 * AgentNodeAdapter Tests
 *
 * Tests for ProseMirror-based agent response node manipulation.
 */

import { describe, test, expect, beforeEach, vi } from 'vitest'
import { AgentNodeAdapter } from '../../../infrastructure/prosemirror/agent-node-adapter'
import { AgentResponse } from '../../../domain/entities/agent-response'
import { NodeId } from '../../../domain/value-objects/node-id'
import { EditorView } from '@milkdown/prose/view'
import { EditorState } from '@milkdown/prose/state'
import { Schema } from '@milkdown/prose/model'
import { IMarkdownParserAdapter } from '../../../application/interfaces/markdown-parser-adapter'

describe('AgentNodeAdapter', () => {
  let adapter: AgentNodeAdapter
  let mockView: EditorView
  let mockState: EditorState
  let schema: Schema
  let mockDispatch: ReturnType<typeof vi.fn>
  let mockParser: IMarkdownParserAdapter

  beforeEach(() => {
    // Create schema with agent_response node (matches actual schema)
    schema = new Schema({
      nodes: {
        doc: { content: 'block+' },
        paragraph: { content: 'inline*', group: 'block' },
        text: { group: 'inline' },
        agent_response: {
          group: 'inline',
          inline: true,
          atom: true,
          attrs: {
            nodeId: { default: '' },
            state: { default: 'streaming' },
            content: { default: '' },
            error: { default: '' }
          },
          parseDOM: [{ tag: 'span.agent-response' }],
          toDOM: () => ['span', { class: 'agent-response' }, 0]
        }
      }
    })

    mockDispatch = vi.fn()

    // Create mock parser adapter
    mockParser = {
      parse: vi.fn()
    }

    // Create initial state
    mockState = EditorState.create({
      doc: schema.node('doc', null, [
        schema.node('paragraph', null, [schema.text('Hello')])
      ]),
      schema
    })

    mockView = {
      state: mockState,
      dispatch: mockDispatch
    } as any

    adapter = new AgentNodeAdapter(mockView, schema, mockParser)
  })

  describe('createAndInsert', () => {
    test('creates agent response node and dispatches transaction', () => {
      // Create document with @j mention
      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [schema.text('@j test question')])
        ]),
        schema
      })

      mockView.state = mockState

      const nodeId = NodeId.generate()
      const mention = {
        text: '@j test question',
        from: 1, // start of paragraph
        to: 17, // end of text
        question: 'test question'
      }

      adapter.createAndInsert(mention, nodeId)

      expect(mockDispatch).toHaveBeenCalled()
      const transaction = mockDispatch.mock.calls[0][0]
      expect(transaction.steps).toHaveLength(2) // delete + insert
    })
  })

  describe('update', () => {
    test('updates node attributes when node exists', () => {
      const nodeId = NodeId.generate()
      const response = AgentResponse.create(nodeId)
      const updatedResponse = response.appendChunk('Hello')

      // Add agent_response node to document inside a paragraph
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: '',
        error: ''
      })

      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      adapter.update(updatedResponse)

      expect(mockDispatch).toHaveBeenCalled()
    })

    test('does nothing when node does not exist', () => {
      const nodeId = NodeId.generate()
      const response = AgentResponse.create(nodeId)

      adapter.update(response)

      // Should not throw, but also should not dispatch
      expect(mockDispatch).not.toHaveBeenCalled()
    })
  })

  describe('appendChunk', () => {
    test('appends chunk to node content', () => {
      const nodeId = NodeId.generate()

      // Add agent_response node to document inside a paragraph
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: 'Hello',
        error: ''
      })

      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      adapter.appendChunk(nodeId, ' world')

      expect(mockDispatch).toHaveBeenCalled()
      const transaction = mockDispatch.mock.calls[0][0]
      // Verify the new content would be 'Hello world'
      // The agent node is the first child of the paragraph (firstChild.firstChild)
      expect(transaction.doc.firstChild?.firstChild?.attrs.content).toBe('Hello world')
    })
  })

  describe('exists', () => {
    test('returns true when node exists', () => {
      const nodeId = NodeId.generate()

      // Add agent_response node to document inside a paragraph
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: '',
        error: ''
      })

      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      const result = adapter.exists(nodeId)

      expect(result).toBe(true)
    })

    test('returns false when node does not exist', () => {
      const nodeId = NodeId.generate()

      const result = adapter.exists(nodeId)

      expect(result).toBe(false)
    })
  })

  describe('replaceWithMarkdown', () => {
    test('does nothing when parser returns null', () => {
      const nodeId = NodeId.generate()
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: '',
        error: ''
      })

      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      vi.mocked(mockParser.parse).mockReturnValue(null)

      adapter.replaceWithMarkdown(nodeId, '# Invalid')

      expect(mockDispatch).not.toHaveBeenCalled()
    })

    test('does nothing when parser returns empty content', () => {
      const nodeId = NodeId.generate()
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: '',
        error: ''
      })

      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      vi.mocked(mockParser.parse).mockReturnValue({ content: [] })

      adapter.replaceWithMarkdown(nodeId, '')

      expect(mockDispatch).not.toHaveBeenCalled()
    })

    test('does nothing when node does not exist', () => {
      const nodeId = NodeId.generate()

      vi.mocked(mockParser.parse).mockReturnValue({
        content: [schema.node('paragraph', null, [schema.text('Parsed content')])]
      })

      adapter.replaceWithMarkdown(nodeId, '# Test')

      expect(mockDispatch).not.toHaveBeenCalled()
    })

    test('replaces agent node with single inline paragraph in paragraph context', () => {
      const nodeId = NodeId.generate()
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: 'loading...',
        error: ''
      })

      // Agent node inside a paragraph alone (inline nodes work best alone when atomic)
      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      // Parser returns a single paragraph with inline content
      const parsedParagraph = schema.node('paragraph', null, [schema.text('AI response')])
      vi.mocked(mockParser.parse).mockReturnValue({
        content: [parsedParagraph]
      })

      adapter.replaceWithMarkdown(nodeId, 'AI response')

      expect(mockDispatch).toHaveBeenCalled()
      const transaction = mockDispatch.mock.calls[0][0]
      expect(transaction.steps).toHaveLength(2) // delete + insert
    })

    test('splits paragraph when block nodes are in response', () => {
      const nodeId = NodeId.generate()
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: 'loading...',
        error: ''
      })

      // Agent node inside a paragraph alone
      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      // Parser returns multiple paragraphs (block content)
      const parsedNodes = [
        schema.node('paragraph', null, [schema.text('First para')]),
        schema.node('paragraph', null, [schema.text('Second para')])
      ]
      vi.mocked(mockParser.parse).mockReturnValue({
        content: parsedNodes
      })

      adapter.replaceWithMarkdown(nodeId, 'First para\n\nSecond para')

      expect(mockDispatch).toHaveBeenCalled()
      const transaction = mockDispatch.mock.calls[0][0]
      // Should split paragraph: delete parent, insert blocks
      expect(transaction.steps.length).toBeGreaterThan(0)
    })

    test('replaces agent node with block content at top level', () => {
      const nodeId = NodeId.generate()
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: 'loading...',
        error: ''
      })

      // Agent node inside an empty paragraph at top level
      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      // Parser returns block content
      const parsedNodes = [
        schema.node('paragraph', null, [schema.text('Response para')])
      ]
      vi.mocked(mockParser.parse).mockReturnValue({
        content: parsedNodes
      })

      adapter.replaceWithMarkdown(nodeId, 'Response para')

      expect(mockDispatch).toHaveBeenCalled()
      const transaction = mockDispatch.mock.calls[0][0]
      // Should split: delete parent paragraph, insert block content
      expect(transaction.steps.length).toBeGreaterThan(0)
    })

    test('handles multiple inline nodes in paragraph context', () => {
      const nodeId = NodeId.generate()
      const agentNode = schema.nodes.agent_response.create({
        nodeId: nodeId.value,
        state: 'streaming',
        content: 'loading...',
        error: ''
      })

      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [agentNode])
        ]),
        schema
      })

      mockView.state = mockState

      // Parser returns multiple text nodes (still inline, no paragraphs)
      const textNode1 = schema.text('Part 1 ')
      const textNode2 = schema.text('Part 2')
      vi.mocked(mockParser.parse).mockReturnValue({
        content: [textNode1, textNode2] as any
      })

      adapter.replaceWithMarkdown(nodeId, 'Part 1 Part 2')

      expect(mockDispatch).toHaveBeenCalled()
    })
  })
})
