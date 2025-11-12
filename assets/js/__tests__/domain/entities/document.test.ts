import { describe, test, expect } from 'vitest'
import { Document } from '../../../domain/entities/document'
import { DocumentId } from '../../../domain/value-objects/document-id'
import { DocumentContent } from '../../../domain/value-objects/document-content'
import { DocumentChange } from '../../../domain/entities/document-change'
import { UserId } from '../../../domain/value-objects/user-id'

describe('Document', () => {
  describe('constructor', () => {
    test('creates Document with all properties', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Hello')
      const createdAt = new Date('2025-11-12T10:00:00Z')
      const updatedAt = new Date('2025-11-12T11:00:00Z')
      const version = 2
      const changes: DocumentChange[] = []

      const doc = new Document(documentId, content, createdAt, updatedAt, version, changes)

      expect(doc.documentId.equals(documentId)).toBe(true)
      expect(doc.content.equals(content)).toBe(true)
      expect(doc.createdAt).toEqual(createdAt)
      expect(doc.updatedAt).toEqual(updatedAt)
      expect(doc.version).toBe(version)
      expect(doc.changes).toEqual(changes)
    })

    test('creates Document with empty content', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('')
      const createdAt = new Date()
      const updatedAt = new Date()

      const doc = new Document(documentId, content, createdAt, updatedAt, 1, [])

      expect(doc.content.isEmpty()).toBe(true)
    })

    test('creates Document with change history', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Title')
      const userId = new UserId('user-1')
      const changes = [
        DocumentChange.createChange(userId),
        DocumentChange.updateChange(userId)
      ]

      const doc = new Document(documentId, content, new Date(), new Date(), 2, changes)

      expect(doc.changes).toHaveLength(2)
      expect(doc.changes[0].isCreate()).toBe(true)
      expect(doc.changes[1].isUpdate()).toBe(true)
    })
  })

  describe('create factory method', () => {
    test('creates a new document with create change', () => {
      const documentId = new DocumentId('doc-new')
      const content = new DocumentContent('# New Doc')
      const userId = new UserId('user-123')

      const doc = Document.create(documentId, content, userId)

      expect(doc.documentId.equals(documentId)).toBe(true)
      expect(doc.content.equals(content)).toBe(true)
      expect(doc.version).toBe(1)
      expect(doc.changes).toHaveLength(1)
      expect(doc.changes[0].isCreate()).toBe(true)
      expect(doc.changes[0].userId.equals(userId)).toBe(true)
    })

    test('sets createdAt and updatedAt to same time', () => {
      const documentId = new DocumentId('doc-new')
      const content = new DocumentContent('')
      const userId = new UserId('user-123')

      const doc = Document.create(documentId, content, userId)

      expect(doc.createdAt.getTime()).toBe(doc.updatedAt.getTime())
    })

    test('creates document with empty content by default', () => {
      const documentId = new DocumentId('doc-new')
      const content = new DocumentContent('')
      const userId = new UserId('user-123')

      const doc = Document.create(documentId, content, userId)

      expect(doc.content.isEmpty()).toBe(true)
    })
  })

  describe('updateContent', () => {
    test('returns new document with updated content', () => {
      const documentId = new DocumentId('doc-123')
      const oldContent = new DocumentContent('# Old')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, oldContent, userId)

      const newContent = new DocumentContent('# New')
      const updatedDoc = doc.updateContent(newContent, userId)

      expect(updatedDoc.content.equals(newContent)).toBe(true)
      expect(updatedDoc.content.equals(oldContent)).toBe(false)
    })

    test('returns new instance (immutability)', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Original')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      const newContent = new DocumentContent('# Updated')
      const updatedDoc = doc.updateContent(newContent, userId)

      expect(updatedDoc).not.toBe(doc)
      expect(doc.content.equals(content)).toBe(true) // Original unchanged
    })

    test('increments version', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Original')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      const newContent = new DocumentContent('# Updated')
      const updatedDoc = doc.updateContent(newContent, userId)

      expect(updatedDoc.version).toBe(doc.version + 1)
    })

    test('updates updatedAt timestamp', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Original')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      // Wait a tiny bit to ensure timestamp difference
      const newContent = new DocumentContent('# Updated')
      const updatedDoc = doc.updateContent(newContent, userId)

      expect(updatedDoc.updatedAt.getTime()).toBeGreaterThanOrEqual(doc.updatedAt.getTime())
    })

    test('does not change createdAt', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Original')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      const newContent = new DocumentContent('# Updated')
      const updatedDoc = doc.updateContent(newContent, userId)

      expect(updatedDoc.createdAt).toEqual(doc.createdAt)
    })

    test('appends update change to history', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Original')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      const newContent = new DocumentContent('# Updated')
      const updatedDoc = doc.updateContent(newContent, userId)

      expect(updatedDoc.changes).toHaveLength(2)
      expect(updatedDoc.changes[0].isCreate()).toBe(true)
      expect(updatedDoc.changes[1].isUpdate()).toBe(true)
    })
  })

  describe('isEmpty', () => {
    test('returns true for document with empty content', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      expect(doc.isEmpty()).toBe(true)
    })

    test('returns false for document with content', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Hello')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      expect(doc.isEmpty()).toBe(false)
    })
  })

  describe('getWordCount', () => {
    test('returns 0 for empty document', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      expect(doc.getWordCount()).toBe(0)
    })

    test('returns correct word count for simple text', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('Hello World Test')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      expect(doc.getWordCount()).toBe(3)
    })

    test('excludes markdown syntax from word count', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Hello World')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      expect(doc.getWordCount()).toBe(2) // Only counts "Hello World", not "#"
    })

    test('handles multiple spaces', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('Hello    World')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      expect(doc.getWordCount()).toBe(2)
    })

    test('handles newlines', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('Hello\nWorld\nTest')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      expect(doc.getWordCount()).toBe(3)
    })
  })

  describe('getChangeHistory', () => {
    test('returns all changes', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Original')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      const updated = doc.updateContent(new DocumentContent('# Updated'), userId)
      const history = updated.getChangeHistory()

      expect(history).toHaveLength(2)
      expect(history[0].isCreate()).toBe(true)
      expect(history[1].isUpdate()).toBe(true)
    })

    test('returns empty array for new document', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      const history = doc.getChangeHistory()

      expect(history).toHaveLength(1)
      expect(history[0].isCreate()).toBe(true)
    })
  })

  describe('hasBeenModified', () => {
    test('returns false for newly created document', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# New')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      expect(doc.hasBeenModified()).toBe(false)
    })

    test('returns true after content update', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Original')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      const updated = doc.updateContent(new DocumentContent('# Updated'), userId)

      expect(updated.hasBeenModified()).toBe(true)
    })

    test('returns true for document with multiple updates', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Original')
      const userId = new UserId('user-1')
      let doc = Document.create(documentId, content, userId)

      doc = doc.updateContent(new DocumentContent('# Update 1'), userId)
      doc = doc.updateContent(new DocumentContent('# Update 2'), userId)

      expect(doc.hasBeenModified()).toBe(true)
    })
  })

  describe('immutability', () => {
    test('properties are readonly', () => {
      const documentId = new DocumentId('doc-123')
      const content = new DocumentContent('# Test')
      const userId = new UserId('user-1')
      const doc = Document.create(documentId, content, userId)

      // TypeScript prevents modification at compile time
      expect(doc.documentId).toBeInstanceOf(DocumentId)
      expect(doc.content).toBeInstanceOf(DocumentContent)
      expect(doc.createdAt).toBeInstanceOf(Date)
      expect(doc.updatedAt).toBeInstanceOf(Date)
      expect(doc.version).toBe(1)
      expect(doc.changes).toBeInstanceOf(Array)
    })
  })
})
