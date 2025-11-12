/**
 * Document Entity
 *
 * Represents a document in the domain with its content, metadata, and change history.
 * Immutable entity that provides document operations following business rules.
 *
 * This is a pure domain entity with no framework dependencies.
 * Documents track their entire change history and enforce business rules:
 * - Version increments on each update
 * - updatedAt changes on content updates
 * - createdAt never changes
 * - Change history is append-only
 *
 * @example
 * ```typescript
 * // Create a new document
 * const docId = new DocumentId('doc-123')
 * const content = new DocumentContent('# Hello World')
 * const userId = new UserId('user-456')
 * const doc = Document.create(docId, content, userId)
 *
 * // Update document content
 * const newContent = new DocumentContent('# Updated Content')
 * const updatedDoc = doc.updateContent(newContent, userId)
 *
 * // Check document state
 * console.log(updatedDoc.isEmpty()) // false
 * console.log(updatedDoc.getWordCount()) // 2
 * console.log(updatedDoc.hasBeenModified()) // true
 * console.log(updatedDoc.version) // 2
 * ```
 *
 * @module domain/entities
 */

import { DocumentId } from '../value-objects/document-id'
import { DocumentContent } from '../value-objects/document-content'
import { DocumentChange } from './document-change'
import { UserId } from '../value-objects/user-id'

export class Document {
  /**
   * Unique identifier for the document
   * @readonly
   */
  public readonly documentId: DocumentId

  /**
   * Current content of the document (markdown)
   * @readonly
   */
  public readonly content: DocumentContent

  /**
   * When the document was created (never changes)
   * @readonly
   */
  public readonly createdAt: Date

  /**
   * When the document was last updated
   * @readonly
   */
  public readonly updatedAt: Date

  /**
   * Version number (increments on each update)
   * @readonly
   */
  public readonly version: number

  /**
   * Complete change history (append-only)
   * @readonly
   */
  public readonly changes: readonly DocumentChange[]

  /**
   * Creates a new Document entity
   *
   * Use the static factory method `Document.create()` for creating new documents.
   * This constructor is primarily for reconstructing documents from storage.
   *
   * @param documentId - Unique identifier for the document
   * @param content - Document content (markdown)
   * @param createdAt - Creation timestamp
   * @param updatedAt - Last update timestamp
   * @param version - Version number
   * @param changes - Change history
   *
   * @example
   * ```typescript
   * // Reconstruct from storage
   * const doc = new Document(
   *   new DocumentId('doc-123'),
   *   new DocumentContent('# Title'),
   *   new Date('2025-11-12T10:00:00Z'),
   *   new Date('2025-11-12T11:00:00Z'),
   *   2,
   *   [createChange, updateChange]
   * )
   * ```
   */
  constructor(
    documentId: DocumentId,
    content: DocumentContent,
    createdAt: Date,
    updatedAt: Date,
    version: number,
    changes: DocumentChange[]
  ) {
    this.documentId = documentId
    this.content = content
    this.createdAt = createdAt
    this.updatedAt = updatedAt
    this.version = version
    this.changes = changes
  }

  /**
   * Factory method to create a new document
   *
   * Creates a new document with version 1, current timestamp,
   * and a create change in the history.
   *
   * @param documentId - Unique identifier for the document
   * @param content - Initial document content (can be empty)
   * @param userId - User creating the document
   * @returns A new Document entity
   *
   * @example
   * ```typescript
   * const docId = new DocumentId('doc-new')
   * const content = new DocumentContent('# My Document')
   * const userId = new UserId('user-123')
   * const doc = Document.create(docId, content, userId)
   *
   * console.log(doc.version) // 1
   * console.log(doc.changes[0].isCreate()) // true
   * ```
   */
  static create(
    documentId: DocumentId,
    content: DocumentContent,
    userId: UserId
  ): Document {
    const now = new Date()
    const createChange = DocumentChange.createChange(userId)
    return new Document(documentId, content, now, now, 1, [createChange])
  }

  /**
   * Update document content
   *
   * Returns a new Document instance with:
   * - Updated content
   * - Incremented version
   * - Updated timestamp
   * - Additional update change in history
   *
   * The original document is unchanged (immutability).
   *
   * @param newContent - The new document content
   * @param userId - User making the update
   * @returns A new Document instance with updated content
   *
   * @example
   * ```typescript
   * const original = Document.create(
   *   new DocumentId('doc-1'),
   *   new DocumentContent('# Old'),
   *   new UserId('user-1')
   * )
   *
   * const updated = original.updateContent(
   *   new DocumentContent('# New'),
   *   new UserId('user-1')
   * )
   *
   * console.log(updated.version) // 2
   * console.log(updated.hasBeenModified()) // true
   * console.log(original.version) // 1 (unchanged)
   * ```
   */
  updateContent(newContent: DocumentContent, userId: UserId): Document {
    const updateChange = DocumentChange.updateChange(userId)
    return new Document(
      this.documentId,
      newContent,
      this.createdAt,
      new Date(),
      this.version + 1,
      [...this.changes, updateChange]
    )
  }

  /**
   * Check if the document is empty
   *
   * A document is empty when its content is an empty string.
   *
   * @returns true if content is empty
   *
   * @example
   * ```typescript
   * const emptyDoc = Document.create(
   *   new DocumentId('doc-1'),
   *   new DocumentContent(''),
   *   new UserId('user-1')
   * )
   * console.log(emptyDoc.isEmpty()) // true
   *
   * const withContent = emptyDoc.updateContent(
   *   new DocumentContent('# Hello'),
   *   new UserId('user-1')
   * )
   * console.log(withContent.isEmpty()) // false
   * ```
   */
  isEmpty(): boolean {
    return this.content.isEmpty()
  }

  /**
   * Get the word count of the document
   *
   * Counts words in the content, excluding markdown syntax.
   * Returns 0 for empty documents.
   *
   * @returns The number of words in the document
   *
   * @example
   * ```typescript
   * const doc = Document.create(
   *   new DocumentId('doc-1'),
   *   new DocumentContent('# Hello World\n\nThis is a test.'),
   *   new UserId('user-1')
   * )
   * console.log(doc.getWordCount()) // 6 ("Hello World This is a test")
   * ```
   */
  getWordCount(): number {
    if (this.content.isEmpty()) {
      return 0
    }

    // Split on whitespace and filter out empty strings and markdown syntax
    const words = this.content.value
      .split(/\s+/)
      .filter(word => word.length > 0 && !/^[#*\-_`>]$/.test(word))

    return words.length
  }

  /**
   * Get the complete change history
   *
   * Returns a copy of all changes made to the document.
   *
   * @returns Array of all document changes
   *
   * @example
   * ```typescript
   * const doc = Document.create(
   *   new DocumentId('doc-1'),
   *   new DocumentContent('# Original'),
   *   new UserId('user-1')
   * )
   *
   * const updated = doc.updateContent(
   *   new DocumentContent('# Updated'),
   *   new UserId('user-1')
   * )
   *
   * const history = updated.getChangeHistory()
   * console.log(history.length) // 2
   * console.log(history[0].isCreate()) // true
   * console.log(history[1].isUpdate()) // true
   * ```
   */
  getChangeHistory(): DocumentChange[] {
    return [...this.changes]
  }

  /**
   * Check if the document has been modified since creation
   *
   * Returns true if version is greater than 1.
   *
   * @returns true if document has been modified
   *
   * @example
   * ```typescript
   * const doc = Document.create(
   *   new DocumentId('doc-1'),
   *   new DocumentContent('# New'),
   *   new UserId('user-1')
   * )
   * console.log(doc.hasBeenModified()) // false
   *
   * const updated = doc.updateContent(
   *   new DocumentContent('# Updated'),
   *   new UserId('user-1')
   * )
   * console.log(updated.hasBeenModified()) // true
   * ```
   */
  hasBeenModified(): boolean {
    return this.version > 1
  }
}
