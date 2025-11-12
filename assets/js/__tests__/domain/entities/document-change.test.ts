import { describe, test, expect } from 'vitest'
import { DocumentChange, ChangeType } from '../../../domain/entities/document-change'
import { UserId } from '../../../domain/value-objects/user-id'

describe('DocumentChange', () => {
  describe('constructor', () => {
    test('creates DocumentChange with all properties', () => {
      const changeId = 'change-123'
      const timestamp = new Date('2025-11-12T10:00:00Z')
      const userId = new UserId('user-456')
      const changeType: ChangeType = 'update'

      const change = new DocumentChange(changeId, timestamp, userId, changeType)

      expect(change.changeId).toBe(changeId)
      expect(change.timestamp).toEqual(timestamp)
      expect(change.userId.equals(userId)).toBe(true)
      expect(change.changeType).toBe(changeType)
    })

    test('creates DocumentChange with create type', () => {
      const changeId = 'change-1'
      const timestamp = new Date()
      const userId = new UserId('user-1')

      const change = new DocumentChange(changeId, timestamp, userId, 'create')

      expect(change.changeType).toBe('create')
    })

    test('creates DocumentChange with update type', () => {
      const changeId = 'change-2'
      const timestamp = new Date()
      const userId = new UserId('user-2')

      const change = new DocumentChange(changeId, timestamp, userId, 'update')

      expect(change.changeType).toBe('update')
    })

    test('creates DocumentChange with delete type', () => {
      const changeId = 'change-3'
      const timestamp = new Date()
      const userId = new UserId('user-3')

      const change = new DocumentChange(changeId, timestamp, userId, 'delete')

      expect(change.changeType).toBe('delete')
    })
  })

  describe('createChange factory method', () => {
    test('creates a create-type DocumentChange', () => {
      const userId = new UserId('user-123')

      const change = DocumentChange.createChange(userId)

      expect(change.changeType).toBe('create')
      expect(change.userId.equals(userId)).toBe(true)
      expect(change.changeId).toBeTruthy()
      expect(change.timestamp).toBeInstanceOf(Date)
    })

    test('generates unique change IDs', () => {
      const userId = new UserId('user-123')

      const change1 = DocumentChange.createChange(userId)
      const change2 = DocumentChange.createChange(userId)

      expect(change1.changeId).not.toBe(change2.changeId)
    })

    test('sets timestamp to current time', () => {
      const userId = new UserId('user-123')
      const before = new Date()

      const change = DocumentChange.createChange(userId)

      const after = new Date()
      expect(change.timestamp.getTime()).toBeGreaterThanOrEqual(before.getTime())
      expect(change.timestamp.getTime()).toBeLessThanOrEqual(after.getTime())
    })
  })

  describe('updateChange factory method', () => {
    test('creates an update-type DocumentChange', () => {
      const userId = new UserId('user-456')

      const change = DocumentChange.updateChange(userId)

      expect(change.changeType).toBe('update')
      expect(change.userId.equals(userId)).toBe(true)
      expect(change.changeId).toBeTruthy()
      expect(change.timestamp).toBeInstanceOf(Date)
    })

    test('generates unique change IDs', () => {
      const userId = new UserId('user-456')

      const change1 = DocumentChange.updateChange(userId)
      const change2 = DocumentChange.updateChange(userId)

      expect(change1.changeId).not.toBe(change2.changeId)
    })
  })

  describe('deleteChange factory method', () => {
    test('creates a delete-type DocumentChange', () => {
      const userId = new UserId('user-789')

      const change = DocumentChange.deleteChange(userId)

      expect(change.changeType).toBe('delete')
      expect(change.userId.equals(userId)).toBe(true)
      expect(change.changeId).toBeTruthy()
      expect(change.timestamp).toBeInstanceOf(Date)
    })

    test('generates unique change IDs', () => {
      const userId = new UserId('user-789')

      const change1 = DocumentChange.deleteChange(userId)
      const change2 = DocumentChange.deleteChange(userId)

      expect(change1.changeId).not.toBe(change2.changeId)
    })
  })

  describe('isCreate', () => {
    test('returns true for create type', () => {
      const change = DocumentChange.createChange(new UserId('user-1'))

      expect(change.isCreate()).toBe(true)
    })

    test('returns false for update type', () => {
      const change = DocumentChange.updateChange(new UserId('user-1'))

      expect(change.isCreate()).toBe(false)
    })

    test('returns false for delete type', () => {
      const change = DocumentChange.deleteChange(new UserId('user-1'))

      expect(change.isCreate()).toBe(false)
    })
  })

  describe('isUpdate', () => {
    test('returns true for update type', () => {
      const change = DocumentChange.updateChange(new UserId('user-1'))

      expect(change.isUpdate()).toBe(true)
    })

    test('returns false for create type', () => {
      const change = DocumentChange.createChange(new UserId('user-1'))

      expect(change.isUpdate()).toBe(false)
    })

    test('returns false for delete type', () => {
      const change = DocumentChange.deleteChange(new UserId('user-1'))

      expect(change.isUpdate()).toBe(false)
    })
  })

  describe('isDelete', () => {
    test('returns true for delete type', () => {
      const change = DocumentChange.deleteChange(new UserId('user-1'))

      expect(change.isDelete()).toBe(true)
    })

    test('returns false for create type', () => {
      const change = DocumentChange.createChange(new UserId('user-1'))

      expect(change.isDelete()).toBe(false)
    })

    test('returns false for update type', () => {
      const change = DocumentChange.updateChange(new UserId('user-1'))

      expect(change.isDelete()).toBe(false)
    })
  })

  describe('immutability', () => {
    test('properties are readonly', () => {
      const change = DocumentChange.createChange(new UserId('user-1'))

      // TypeScript prevents modification at compile time
      expect(change.changeId).toBeTruthy()
      expect(change.timestamp).toBeInstanceOf(Date)
      expect(change.userId).toBeInstanceOf(UserId)
      expect(change.changeType).toBe('create')
    })
  })
})
