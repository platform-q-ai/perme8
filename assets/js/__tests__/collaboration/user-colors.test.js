import { describe, it, expect } from 'vitest'
import { getUserColor, getColorPalette } from '../../collaboration/user-colors'

describe('UserColors', () => {
  describe('getUserColor', () => {
    it('should return a consistent color for the same user ID', () => {
      const userId = 'user_12345'
      const color1 = getUserColor(userId)
      const color2 = getUserColor(userId)

      expect(color1).toBe(color2)
    })

    it('should return a hex color code', () => {
      const userId = 'user_12345'
      const color = getUserColor(userId)

      expect(color).toMatch(/^#[0-9A-F]{6}$/i)
    })

    it('should return different colors for different users (most likely)', () => {
      const user1Color = getUserColor('user_123')
      const user2Color = getUserColor('user_456')
      const user3Color = getUserColor('user_789')

      // Not guaranteed to be different due to hash collisions,
      // but very likely with a 10-color palette
      const uniqueColors = new Set([user1Color, user2Color, user3Color])
      expect(uniqueColors.size).toBeGreaterThan(1)
    })

    it('should return a color from the palette', () => {
      const userId = 'user_12345'
      const color = getUserColor(userId)
      const palette = getColorPalette()

      expect(palette).toContain(color)
    })

    it('should handle empty string', () => {
      const color = getUserColor('')
      const palette = getColorPalette()

      expect(palette).toContain(color)
    })

    it('should handle long user IDs', () => {
      const userId = 'user_' + 'a'.repeat(1000)
      const color = getUserColor(userId)
      const palette = getColorPalette()

      expect(palette).toContain(color)
    })
  })

  describe('getColorPalette', () => {
    it('should return an array of colors', () => {
      const palette = getColorPalette()

      expect(Array.isArray(palette)).toBe(true)
      expect(palette.length).toBeGreaterThan(0)
    })

    it('should return hex color codes', () => {
      const palette = getColorPalette()

      palette.forEach(color => {
        expect(color).toMatch(/^#[0-9A-F]{6}$/i)
      })
    })

    it('should return a new array each time (immutability)', () => {
      const palette1 = getColorPalette()
      const palette2 = getColorPalette()

      expect(palette1).not.toBe(palette2)
      expect(palette1).toEqual(palette2)
    })
  })
})
