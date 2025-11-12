/**
 * DocumentChange Entity
 *
 * Represents a change made to a document in the domain.
 * Immutable entity that tracks who made a change, when, and what type of change it was.
 *
 * This is a pure domain entity with no framework dependencies.
 * Change history is append-only - changes are never modified after creation.
 *
 * @example
 * ```typescript
 * const userId = new UserId('user-123')
 *
 * // Factory methods for creating changes
 * const create = DocumentChange.createChange(userId)
 * const update = DocumentChange.updateChange(userId)
 * const deletion = DocumentChange.deleteChange(userId)
 *
 * // Check change type
 * console.log(create.isCreate()) // true
 * console.log(update.isUpdate()) // true
 * console.log(deletion.isDelete()) // true
 * ```
 *
 * @module domain/entities
 */

import { UserId } from '../value-objects/user-id'

/**
 * Type of change made to a document
 * - create: Document was created
 * - update: Document content was modified
 * - delete: Document was deleted
 */
export type ChangeType = 'create' | 'update' | 'delete'

export class DocumentChange {
  /**
   * Unique identifier for this change
   * @readonly
   */
  public readonly changeId: string

  /**
   * When the change occurred
   * @readonly
   */
  public readonly timestamp: Date

  /**
   * User who made the change
   * @readonly
   */
  public readonly userId: UserId

  /**
   * Type of change (create, update, or delete)
   * @readonly
   */
  public readonly changeType: ChangeType

  /**
   * Creates a new DocumentChange entity
   *
   * @param changeId - Unique identifier for the change
   * @param timestamp - When the change occurred
   * @param userId - User who made the change
   * @param changeType - Type of change (create, update, or delete)
   *
   * @example
   * ```typescript
   * const change = new DocumentChange(
   *   'change-123',
   *   new Date(),
   *   new UserId('user-456'),
   *   'update'
   * )
   * ```
   */
  constructor(
    changeId: string,
    timestamp: Date,
    userId: UserId,
    changeType: ChangeType
  ) {
    this.changeId = changeId
    this.timestamp = timestamp
    this.userId = userId
    this.changeType = changeType
  }

  /**
   * Factory method to create a "create" type change
   *
   * Generates a unique change ID and sets timestamp to current time.
   *
   * @param userId - User who created the document
   * @returns A new DocumentChange with type 'create'
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-123')
   * const change = DocumentChange.createChange(userId)
   * console.log(change.isCreate()) // true
   * ```
   */
  static createChange(userId: UserId): DocumentChange {
    const changeId = `change-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    return new DocumentChange(changeId, new Date(), userId, 'create')
  }

  /**
   * Factory method to create an "update" type change
   *
   * Generates a unique change ID and sets timestamp to current time.
   *
   * @param userId - User who updated the document
   * @returns A new DocumentChange with type 'update'
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-456')
   * const change = DocumentChange.updateChange(userId)
   * console.log(change.isUpdate()) // true
   * ```
   */
  static updateChange(userId: UserId): DocumentChange {
    const changeId = `change-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    return new DocumentChange(changeId, new Date(), userId, 'update')
  }

  /**
   * Factory method to create a "delete" type change
   *
   * Generates a unique change ID and sets timestamp to current time.
   *
   * @param userId - User who deleted the document
   * @returns A new DocumentChange with type 'delete'
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-789')
   * const change = DocumentChange.deleteChange(userId)
   * console.log(change.isDelete()) // true
   * ```
   */
  static deleteChange(userId: UserId): DocumentChange {
    const changeId = `change-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    return new DocumentChange(changeId, new Date(), userId, 'delete')
  }

  /**
   * Check if this is a "create" type change
   *
   * @returns true if change type is 'create'
   *
   * @example
   * ```typescript
   * const change = DocumentChange.createChange(new UserId('user-1'))
   * console.log(change.isCreate()) // true
   * ```
   */
  isCreate(): boolean {
    return this.changeType === 'create'
  }

  /**
   * Check if this is an "update" type change
   *
   * @returns true if change type is 'update'
   *
   * @example
   * ```typescript
   * const change = DocumentChange.updateChange(new UserId('user-1'))
   * console.log(change.isUpdate()) // true
   * ```
   */
  isUpdate(): boolean {
    return this.changeType === 'update'
  }

  /**
   * Check if this is a "delete" type change
   *
   * @returns true if change type is 'delete'
   *
   * @example
   * ```typescript
   * const change = DocumentChange.deleteChange(new UserId('user-1'))
   * console.log(change.isDelete()) // true
   * ```
   */
  isDelete(): boolean {
    return this.changeType === 'delete'
  }
}
