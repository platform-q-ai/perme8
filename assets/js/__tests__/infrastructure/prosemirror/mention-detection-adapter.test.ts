/**
 * MentionDetectionAdapter Tests
 *
 * Tests for ProseMirror-based mention detection.
 */

import { describe, test, expect, beforeEach } from 'vitest'
import { MentionDetectionAdapter } from '../../../infrastructure/prosemirror/mention-detection-adapter'
import { EditorState } from '@milkdown/prose/state'
import { EditorView } from '@milkdown/prose/view'
import { Schema } from '@milkdown/prose/model'

describe('MentionDetectionAdapter', () => {
  let adapter: MentionDetectionAdapter
  let mockView: EditorView
  let mockState: EditorState
  let schema: Schema

  beforeEach(() => {
    // Create a minimal schema
    schema = new Schema({
      nodes: {
        doc: { content: 'paragraph+' },
        paragraph: { content: 'text*', group: 'block' },
        text: { group: 'inline' }
      }
    })
  })

  describe('detectAtCursor with no mention', () => {
    beforeEach(() => {
      // Create state with plain text
      mockState = EditorState.create({
        doc: schema.node('doc', null, [
          schema.node('paragraph', null, [
            schema.text('Hello world')
          ])
        ]),
        schema
      })

      mockView = {
        state: mockState
      } as EditorView

      adapter = new MentionDetectionAdapter(mockView)
    })

    test('returns null when no mention at cursor', () => {
      const result = adapter.detectAtCursor()

      expect(result).toBeNull()
    })

    test('hasMentionAtCursor returns false', () => {
      const result = adapter.hasMentionAtCursor()

      expect(result).toBe(false)
    })
  })

  describe('detectAtCursor with @j mention', () => {
    beforeEach(() => {
      const para = schema.node('paragraph', null, [schema.text('@j what is TypeScript?')])

      // Create state with @j mention
      mockState = EditorState.create({
        doc: schema.node('doc', null, [para]),
        schema,
        selection: {
          $from: {
            pos: 22, // at end of text
            parent: para,
            parentOffset: 22,
            start: () => 1 // position of paragraph start in doc
          }
        } as any
      })

      mockView = {
        state: mockState
      } as EditorView

      adapter = new MentionDetectionAdapter(mockView)
    })

    test('returns mention detection with question', () => {
      const result = adapter.detectAtCursor()

      expect(result).not.toBeNull()
      expect(result?.text).toBe('@j what is TypeScript?')
      expect(result?.from).toBe(1) // paragraph starts at position 1 in doc
      expect(result?.to).toBe(23)
    })

    test('hasMentionAtCursor returns true', () => {
      const result = adapter.hasMentionAtCursor()

      expect(result).toBe(true)
    })
  })

  describe('detectAtCursor with @j mention (case insensitive)', () => {
    beforeEach(() => {
      const para = schema.node('paragraph', null, [schema.text('@J explain SOLID principles')])

      // Create state with @J mention (uppercase)
      mockState = EditorState.create({
        doc: schema.node('doc', null, [para]),
        schema,
        selection: {
          $from: {
            pos: 27,
            parent: para,
            parentOffset: 27,
            start: () => 1
          }
        } as any
      })

      mockView = {
        state: mockState
      } as EditorView

      adapter = new MentionDetectionAdapter(mockView)
    })

    test('detects uppercase @J mention', () => {
      const result = adapter.detectAtCursor()

      expect(result).not.toBeNull()
      expect(result?.text).toBe('@J explain SOLID principles')
    })
  })

  describe('detectAtCursor with incomplete mention', () => {
    beforeEach(() => {
      const para = schema.node('paragraph', null, [schema.text('@j ')])

      // Create state with just @j and no question
      mockState = EditorState.create({
        doc: schema.node('doc', null, [para]),
        schema,
        selection: {
          $from: {
            pos: 3,
            parent: para,
            parentOffset: 3,
            start: () => 1
          }
        } as any
      })

      mockView = {
        state: mockState
      } as EditorView

      adapter = new MentionDetectionAdapter(mockView)
    })

    test('returns null for incomplete mention', () => {
      const result = adapter.detectAtCursor()

      expect(result).toBeNull()
    })
  })

  describe('detectAtCursor when cursor is before mention', () => {
    beforeEach(() => {
      const para = schema.node('paragraph', null, [schema.text('Hello @j what is this?')])

      // Create state with cursor before @j mention
      mockState = EditorState.create({
        doc: schema.node('doc', null, [para]),
        schema,
        selection: {
          $from: {
            pos: 3, // in "Hello"
            parent: para,
            parentOffset: 3,
            start: () => 1
          }
        } as any
      })

      mockView = {
        state: mockState
      } as EditorView

      adapter = new MentionDetectionAdapter(mockView)
    })

    test('returns null when cursor not in mention', () => {
      const result = adapter.detectAtCursor()

      expect(result).toBeNull()
    })
  })
})
