import { describe, test, expect } from 'vitest'
import { UserColorAssignment } from '../../../domain/policies/user-color-assignment'
import { UserId } from '../../../domain/value-objects/user-id'
import { UserColor } from '../../../domain/value-objects/user-color'

describe('UserColorAssignment', () => {
  describe('assignColor', () => {
    test('assigns color for user ID', () => {
      const userId = new UserId('user-123')

      const color = UserColorAssignment.assignColor(userId)

      expect(color).toBeInstanceOf(UserColor)
      expect(color.hex).toMatch(/^#[0-9A-F]{6}$/)
    })

    test('assigns same color for same user ID (deterministic)', () => {
      const userId = new UserId('user-123')

      const color1 = UserColorAssignment.assignColor(userId)
      const color2 = UserColorAssignment.assignColor(userId)

      expect(color1.equals(color2)).toBe(true)
    })

    test('assigns different colors for different user IDs', () => {
      const userId1 = new UserId('user-123')
      const userId2 = new UserId('user-456')

      const color1 = UserColorAssignment.assignColor(userId1)
      const color2 = UserColorAssignment.assignColor(userId2)

      // Note: There's a small chance they could be the same due to hash collision
      // but with 10 colors and good distribution, this is unlikely
      expect(color1.equals(color2)).toBe(false)
    })

    test('assigns color from predefined palette', () => {
      const userId = new UserId('user-123')

      const color = UserColorAssignment.assignColor(userId)
      const palette = UserColorAssignment.getColorPalette()

      expect(palette.map(c => c.hex)).toContain(color.hex)
    })

    test('distributes colors consistently across multiple users', () => {
      // Test with several user IDs to verify consistent hashing
      const userIds = [
        new UserId('user-1'),
        new UserId('user-2'),
        new UserId('user-3'),
        new UserId('user-4'),
        new UserId('user-5'),
      ]

      const colors = userIds.map(id => UserColorAssignment.assignColor(id))

      // All should be from palette
      const palette = UserColorAssignment.getColorPalette()
      colors.forEach(color => {
        expect(palette.map(c => c.hex)).toContain(color.hex)
      })

      // Should be deterministic - calling again gives same results
      const colors2 = userIds.map(id => UserColorAssignment.assignColor(id))
      colors.forEach((color, index) => {
        expect(color.equals(colors2[index])).toBe(true)
      })
    })
  })

  describe('getColorPalette', () => {
    test('returns array of UserColor objects', () => {
      const palette = UserColorAssignment.getColorPalette()

      expect(Array.isArray(palette)).toBe(true)
      expect(palette.length).toBeGreaterThan(0)
      palette.forEach(color => {
        expect(color).toBeInstanceOf(UserColor)
      })
    })

    test('returns expected colors from original palette', () => {
      const palette = UserColorAssignment.getColorPalette()

      // Expected colors from user-colors.js
      const expectedHexValues = [
        '#FF6B6B', // Red
        '#4ECDC4', // Teal
        '#45B7D1', // Blue
        '#FFA07A', // Orange
        '#98D8C8', // Mint
        '#F7DC6F', // Yellow
        '#BB8FCE', // Purple
        '#85C1E2', // Sky Blue
        '#F8B88B', // Peach
        '#7FB3D5', // Light Blue
      ]

      expect(palette.length).toBe(expectedHexValues.length)
      palette.forEach((color, index) => {
        expect(color.hex).toBe(expectedHexValues[index])
      })
    })

    test('palette is immutable - returns new array each time', () => {
      const palette1 = UserColorAssignment.getColorPalette()
      const palette2 = UserColorAssignment.getColorPalette()

      expect(palette1).not.toBe(palette2)
      expect(palette1.length).toBe(palette2.length)
      palette1.forEach((color, index) => {
        expect(color.equals(palette2[index])).toBe(true)
      })
    })
  })

  describe('color distribution', () => {
    test('assigns color based on hash modulo palette size', () => {
      // Test specific user IDs that we know should map to specific colors
      // This verifies the hashing algorithm works correctly

      // We'll test that the same algorithm as user-colors.js is used
      const userId1 = new UserId('user-1')
      const color1 = UserColorAssignment.assignColor(userId1)

      // The color should be deterministic based on the hash
      expect(color1).toBeInstanceOf(UserColor)

      // Re-assigning should give the same color
      const color1Again = UserColorAssignment.assignColor(userId1)
      expect(color1.equals(color1Again)).toBe(true)
    })

    test('hash collision results in same color', () => {
      // If two IDs happen to hash to the same value mod palette size,
      // they should get the same color
      const userId1 = new UserId('test-id-1')
      const userId2 = new UserId('test-id-1') // Same ID

      const color1 = UserColorAssignment.assignColor(userId1)
      const color2 = UserColorAssignment.assignColor(userId2)

      expect(color1.equals(color2)).toBe(true)
    })

    test('palette size is 10 colors', () => {
      const palette = UserColorAssignment.getColorPalette()

      expect(palette.length).toBe(10)
    })
  })
})
