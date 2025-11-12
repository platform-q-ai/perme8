import { describe, test, expect, beforeEach } from 'vitest'
import { UserAwareness } from '../../../domain/entities/user-awareness'
import { UserId } from '../../../domain/value-objects/user-id'
import { UserName } from '../../../domain/value-objects/user-name'
import { UserColor } from '../../../domain/value-objects/user-color'
import { Selection } from '../../../domain/value-objects/selection'
import { CursorPosition } from '../../../domain/entities/cursor-position'

describe('UserAwareness', () => {
  let userId: UserId
  let userName: UserName
  let userColor: UserColor

  beforeEach(() => {
    userId = new UserId('user-123')
    userName = new UserName('John Doe')
    userColor = new UserColor('#FF6B6B')
  })

  describe('create', () => {
    test('creates UserAwareness with user identity', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      expect(awareness.userId).toBe(userId)
      expect(awareness.userName).toBe(userName)
      expect(awareness.userColor).toBe(userColor)
      expect(awareness.selection).toBeNull()
      expect(awareness.cursorPosition).toBeNull()
      expect(awareness.lastActivity).toBeInstanceOf(Date)
    })

    test('sets lastActivity to current time', () => {
      const beforeCreate = Date.now()
      const awareness = UserAwareness.create(userId, userName, userColor)
      const afterCreate = Date.now()

      const timestamp = awareness.lastActivity.getTime()
      expect(timestamp).toBeGreaterThanOrEqual(beforeCreate)
      expect(timestamp).toBeLessThanOrEqual(afterCreate)
    })

    test('initializes with no selection', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      expect(awareness.selection).toBeNull()
      expect(awareness.hasSelection()).toBe(false)
    })

    test('initializes with no cursor position', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      expect(awareness.cursorPosition).toBeNull()
      expect(awareness.hasCursor()).toBe(false)
    })
  })

  describe('constructor', () => {
    test('creates UserAwareness with all properties', () => {
      const selection = new Selection(5, 10)
      const cursorPosition = CursorPosition.create(userId, 10)
      const lastActivity = new Date('2025-11-12T10:00:00Z')

      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        selection,
        cursorPosition,
        lastActivity
      )

      expect(awareness.userId).toBe(userId)
      expect(awareness.userName).toBe(userName)
      expect(awareness.userColor).toBe(userColor)
      expect(awareness.selection).toBe(selection)
      expect(awareness.cursorPosition).toBe(cursorPosition)
      expect(awareness.lastActivity).toBe(lastActivity)
    })

    test('allows null selection', () => {
      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        null,
        null,
        new Date()
      )

      expect(awareness.selection).toBeNull()
    })

    test('allows null cursor position', () => {
      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        null,
        null,
        new Date()
      )

      expect(awareness.cursorPosition).toBeNull()
    })
  })

  describe('updateSelection', () => {
    test('updates selection and lastActivity', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)

      const updated = awareness.updateSelection(selection)

      expect(updated.selection).toBe(selection)
      expect(updated.lastActivity.getTime()).toBeGreaterThanOrEqual(awareness.lastActivity.getTime())
    })

    test('preserves other properties', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)

      const updated = awareness.updateSelection(selection)

      expect(updated.userId).toBe(userId)
      expect(updated.userName).toBe(userName)
      expect(updated.userColor).toBe(userColor)
    })

    test('does not mutate original awareness', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)

      const updated = awareness.updateSelection(selection)

      expect(awareness.selection).toBeNull()
      expect(updated.selection).toBe(selection)
    })

    test('updates existing selection', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection1 = new Selection(5, 10)
      const selection2 = new Selection(15, 20)

      const withSelection = awareness.updateSelection(selection1)
      const updated = withSelection.updateSelection(selection2)

      expect(updated.selection).toBe(selection2)
      expect(updated.selection?.anchor).toBe(15)
    })

    test('preserves cursor position when updating selection', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const withCursor = awareness.updateCursor(10)
      const selection = new Selection(5, 10)

      const updated = withCursor.updateSelection(selection)

      expect(updated.cursorPosition).not.toBeNull()
    })
  })

  describe('updateCursor', () => {
    test('creates new cursor position and updates lastActivity', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      const updated = awareness.updateCursor(42)

      expect(updated.cursorPosition).not.toBeNull()
      expect(updated.cursorPosition?.position).toBe(42)
      expect(updated.cursorPosition?.userId).toBe(userId)
      expect(updated.lastActivity.getTime()).toBeGreaterThanOrEqual(awareness.lastActivity.getTime())
    })

    test('preserves other properties', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      const updated = awareness.updateCursor(42)

      expect(updated.userId).toBe(userId)
      expect(updated.userName).toBe(userName)
      expect(updated.userColor).toBe(userColor)
    })

    test('does not mutate original awareness', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      const updated = awareness.updateCursor(42)

      expect(awareness.cursorPosition).toBeNull()
      expect(updated.cursorPosition?.position).toBe(42)
    })

    test('updates existing cursor position', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const withCursor = awareness.updateCursor(10)

      const updated = withCursor.updateCursor(20)

      expect(updated.cursorPosition?.position).toBe(20)
    })

    test('preserves selection when updating cursor', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)
      const withSelection = awareness.updateSelection(selection)

      const updated = withSelection.updateCursor(10)

      expect(updated.selection).toBe(selection)
    })

    test('accepts zero position', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      const updated = awareness.updateCursor(0)

      expect(updated.cursorPosition?.position).toBe(0)
    })
  })

  describe('clearSelection', () => {
    test('removes selection and updates lastActivity', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)
      const withSelection = awareness.updateSelection(selection)

      const cleared = withSelection.clearSelection()

      expect(cleared.selection).toBeNull()
      expect(cleared.lastActivity.getTime()).toBeGreaterThanOrEqual(withSelection.lastActivity.getTime())
    })

    test('preserves other properties', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)
      const withSelection = awareness.updateSelection(selection)

      const cleared = withSelection.clearSelection()

      expect(cleared.userId).toBe(userId)
      expect(cleared.userName).toBe(userName)
      expect(cleared.userColor).toBe(userColor)
    })

    test('does not mutate original awareness', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)
      const withSelection = awareness.updateSelection(selection)

      const cleared = withSelection.clearSelection()

      expect(withSelection.selection).toBe(selection)
      expect(cleared.selection).toBeNull()
    })

    test('preserves cursor position when clearing selection', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)
      const withBoth = awareness
        .updateSelection(selection)
        .updateCursor(10)

      const cleared = withBoth.clearSelection()

      expect(cleared.cursorPosition).not.toBeNull()
      expect(cleared.cursorPosition?.position).toBe(10)
    })

    test('clearing already null selection still updates lastActivity', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      const cleared = awareness.clearSelection()

      expect(cleared.selection).toBeNull()
      expect(cleared.lastActivity.getTime()).toBeGreaterThanOrEqual(awareness.lastActivity.getTime())
    })
  })

  describe('isActive', () => {
    test('returns true for recent activity', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      expect(awareness.isActive(5000)).toBe(true)
    })

    test('returns false for old activity', () => {
      const oldTimestamp = new Date(Date.now() - 10000) // 10 seconds ago
      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        null,
        null,
        oldTimestamp
      )

      expect(awareness.isActive(5000)).toBe(false)
    })

    test('returns true when exactly at max inactive time', () => {
      const timestamp = new Date(Date.now() - 5000) // Exactly 5 seconds ago
      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        null,
        null,
        timestamp
      )

      expect(awareness.isActive(5000)).toBe(true)
    })

    test('returns false when just over max inactive time', () => {
      const timestamp = new Date(Date.now() - 5001) // Just over 5 seconds ago
      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        null,
        null,
        timestamp
      )

      expect(awareness.isActive(5000)).toBe(false)
    })

    test('handles zero max inactive time', () => {
      const pastTimestamp = new Date(Date.now() - 1)
      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        null,
        null,
        pastTimestamp
      )

      expect(awareness.isActive(0)).toBe(false)
    })

    test('handles very large max inactive time', () => {
      const oldTimestamp = new Date(Date.now() - 1000000) // Very old
      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        null,
        null,
        oldTimestamp
      )

      expect(awareness.isActive(10000000)).toBe(true)
    })

    test('returns true for future timestamp', () => {
      // Edge case: awareness with future timestamp (clock skew)
      const futureTimestamp = new Date(Date.now() + 5000)
      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        null,
        null,
        futureTimestamp
      )

      expect(awareness.isActive(1000)).toBe(true)
    })
  })

  describe('hasSelection', () => {
    test('returns true when selection exists', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)
      const withSelection = awareness.updateSelection(selection)

      expect(withSelection.hasSelection()).toBe(true)
    })

    test('returns false when selection is null', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      expect(awareness.hasSelection()).toBe(false)
    })

    test('returns false after clearing selection', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)
      const withSelection = awareness.updateSelection(selection)
      const cleared = withSelection.clearSelection()

      expect(cleared.hasSelection()).toBe(false)
    })
  })

  describe('hasCursor', () => {
    test('returns true when cursor position exists', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const withCursor = awareness.updateCursor(10)

      expect(withCursor.hasCursor()).toBe(true)
    })

    test('returns false when cursor position is null', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)

      expect(awareness.hasCursor()).toBe(false)
    })
  })

  describe('immutability', () => {
    test('creates immutable entity', () => {
      const selection = new Selection(5, 10)
      const cursorPosition = CursorPosition.create(userId, 10)
      const lastActivity = new Date('2025-11-12T10:00:00Z')

      const awareness = new UserAwareness(
        userId,
        userName,
        userColor,
        selection,
        cursorPosition,
        lastActivity
      )

      // Properties are readonly - TypeScript prevents modification at compile time
      expect(awareness.userId).toBe(userId)
      expect(awareness.selection).toBe(selection)

      // Update operations create new instances
      const updated = awareness.updateCursor(20)
      expect(awareness.cursorPosition).toBe(cursorPosition)
      expect(updated.cursorPosition?.position).toBe(20)
    })

    test('chaining operations creates new instances', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)

      const updated = awareness
        .updateSelection(selection)
        .updateCursor(10)
        .clearSelection()

      expect(awareness.selection).toBeNull()
      expect(awareness.cursorPosition).toBeNull()
      expect(updated.selection).toBeNull()
      expect(updated.cursorPosition?.position).toBe(10)
    })
  })

  describe('integration with value objects', () => {
    test('preserves UserId value object', () => {
      const userId1 = new UserId('user-123')
      const userId2 = new UserId('user-123')

      const awareness1 = UserAwareness.create(userId1, userName, userColor)
      const awareness2 = UserAwareness.create(userId2, userName, userColor)

      expect(awareness1.userId.equals(awareness2.userId)).toBe(true)
    })

    test('preserves UserName value object', () => {
      const name1 = new UserName('John Doe')
      const name2 = new UserName('John Doe')

      const awareness1 = UserAwareness.create(userId, name1, userColor)
      const awareness2 = UserAwareness.create(userId, name2, userColor)

      expect(awareness1.userName.equals(awareness2.userName)).toBe(true)
    })

    test('preserves UserColor value object', () => {
      const color1 = new UserColor('#FF6B6B')
      const color2 = new UserColor('#ff6b6b')

      const awareness1 = UserAwareness.create(userId, userName, color1)
      const awareness2 = UserAwareness.create(userId, userName, color2)

      expect(awareness1.userColor.equals(awareness2.userColor)).toBe(true)
    })

    test('preserves Selection value object', () => {
      const awareness = UserAwareness.create(userId, userName, userColor)
      const selection = new Selection(5, 10)

      const updated = awareness.updateSelection(selection)

      expect(updated.selection?.equals(selection)).toBe(true)
    })
  })
})
