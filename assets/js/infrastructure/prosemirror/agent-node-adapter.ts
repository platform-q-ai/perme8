/**
 * AgentNodeAdapter
 *
 * ProseMirror-based implementation for manipulating agent response nodes.
 * Implements IAgentNodeAdapter interface.
 */

import { IAgentNodeAdapter } from '../../application/interfaces/agent-node-adapter'
import { IMarkdownParserAdapter } from '../../application/interfaces/markdown-parser-adapter'
import { AgentResponse } from '../../domain/entities/agent-response'
import { NodeId } from '../../domain/value-objects/node-id'
import { MentionDetection } from '../../domain/policies/mention-detection-policy'
import { EditorView } from '@milkdown/prose/view'
import { Schema, Node as ProseMirrorNode } from '@milkdown/prose/model'

export class AgentNodeAdapter implements IAgentNodeAdapter {
  constructor(
    private view: EditorView,
    private schema: Schema,
    private parser: IMarkdownParserAdapter
  ) {}

  createAndInsert(mention: MentionDetection, nodeId: NodeId): void {
    const { state } = this.view
    const agentNode = this.createAgentResponseNode(nodeId)

    const tr = state.tr
    tr.delete(mention.from, mention.to)
    tr.insert(mention.from, agentNode)

    this.view.dispatch(tr)
  }

  update(response: AgentResponse): void {
    const { nodePos, node } = this.findNodeById(response.nodeId)

    if (nodePos === null || !node) {
      console.warn(`Agent response node not found: ${response.nodeId.value}`)
      return
    }

    const { state } = this.view
    const newAttrs = {
      ...node.attrs,
      state: response.state,
      content: response.content || '',
      error: response.error || ''
    }

    const tr = state.tr.setNodeMarkup(nodePos, null, newAttrs)
    this.view.dispatch(tr)
  }

  appendChunk(nodeId: NodeId, chunk: string): void {
    const { nodePos, node } = this.findNodeById(nodeId)

    if (nodePos === null || !node) {
      console.warn(`Agent response node not found: ${nodeId.value}`)
      return
    }

    const { state } = this.view
    const newContent = (node.attrs.content || '') + chunk
    const newAttrs = {
      ...node.attrs,
      content: newContent
    }

    const tr = state.tr.setNodeMarkup(nodePos, null, newAttrs)
    this.view.dispatch(tr)
  }

  replaceWithMarkdown(nodeId: NodeId, markdown: string): void {
    // Parse markdown into ProseMirror nodes
    const parsed = this.parser.parse(markdown)

    // Handle parser errors
    if (!parsed || !parsed.content || parsed.content.length === 0) {
      console.error('[AgentNodeAdapter] Failed to parse markdown:', parsed)
      return
    }

    // Find the agent response node
    const { state } = this.view
    const { doc } = state

    let nodePos: number | null = null
    let parentNode: ProseMirrorNode | null = null
    let indexInParent: number | null = null

    doc.descendants((node, pos, parent, index) => {
      if (node.type.name === 'agent_response' && node.attrs.nodeId === nodeId.value) {
        nodePos = pos
        parentNode = parent
        indexInParent = index
        return false
      }
      return true
    })

    if (nodePos === null || parentNode === null || indexInParent === null) {
      console.warn('[AgentNodeAdapter] Agent response node not found:', nodeId.value)
      return
    }

    // TypeScript type assertion after null checks
    const validParent: ProseMirrorNode = parentNode
    const validIndex: number = indexInParent

    const tr = state.tr
    const nodes = parsed.content

    // Calculate parent start position
    const parentStart = nodePos - validIndex - 1

    // If the AI response is inside a paragraph, handle inline vs block content
    if (validParent.type.name === 'paragraph') {
      // Check if we have any block-level nodes (paragraphs, headings, lists, etc.)
      const hasBlockNodes = nodes.some(node => !node.isInline && node.type.name !== 'text')

      if (!hasBlockNodes && nodes.length === 1 && nodes[0].type.name === 'paragraph') {
        // Single paragraph - delete AI node and insert its content inline
        const inlineContent = nodes[0].content
        tr.delete(nodePos, nodePos + 1)
        tr.insert(nodePos, inlineContent)
      } else if (hasBlockNodes) {
        // Has block nodes - split the paragraph at the AI node position
        // and insert the block nodes at the split point

        // Split the paragraph at the AI node position
        const beforeContent = validParent.content.cut(0, validIndex)
        const afterContent = validParent.content.cut(validIndex + 1)

        // Delete the entire parent paragraph
        tr.delete(parentStart, parentStart + validParent.nodeSize)

        let currentPos = parentStart

        // Insert before-content as a paragraph if it exists
        if (beforeContent.size > 0) {
          const beforePara = this.schema.nodes.paragraph.create(null, beforeContent)
          tr.insert(currentPos, beforePara)
          currentPos += beforePara.nodeSize
        }

        // Insert all block nodes at the current position
        nodes.forEach((node) => {
          tr.insert(currentPos, node)
          currentPos += node.nodeSize
        })

        // Insert after-content as a paragraph if it exists
        if (afterContent.size > 0) {
          const afterPara = this.schema.nodes.paragraph.create(null, afterContent)
          tr.insert(currentPos, afterPara)
        }
      } else {
        // Multiple inline nodes or single non-paragraph node
        tr.delete(nodePos, nodePos + 1)
        let currentPos: number = nodePos
        nodes.forEach((node) => {
          tr.insert(currentPos, node)
          currentPos += node.nodeSize
        })
      }
    } else {
      // Not in a paragraph, delete AI node and insert all parsed nodes at the deletion point
      tr.delete(nodePos, nodePos + 1)
      let currentPos: number = nodePos
      nodes.forEach((node) => {
        tr.insert(currentPos, node)
        currentPos += node.nodeSize
      })
    }

    this.view.dispatch(tr)
  }

  exists(nodeId: NodeId): boolean {
    const { nodePos } = this.findNodeById(nodeId)
    return nodePos !== null
  }

  private createAgentResponseNode(nodeId: NodeId) {
    const nodeType = this.schema.nodes.agent_response

    if (!nodeType) {
      console.error('agent_response node type not found in schema')
      // Fallback to paragraph
      return this.schema.nodes.paragraph.create(null, this.schema.text('[Agent Response]'))
    }

    return nodeType.create({
      nodeId: nodeId.value,
      state: 'streaming',
      content: '',
      error: ''
    })
  }

  private findNodeById(nodeId: NodeId): { nodePos: number | null; node: any | null } {
    const { state } = this.view
    const { doc } = state

    let nodePos: number | null = null
    let nodeToUpdate: any | null = null

    doc.descendants((node, pos) => {
      if (node.type.name === 'agent_response' && node.attrs.nodeId === nodeId.value) {
        nodePos = pos
        nodeToUpdate = node
        return false
      }
      return true
    })

    return { nodePos, node: nodeToUpdate }
  }
}
