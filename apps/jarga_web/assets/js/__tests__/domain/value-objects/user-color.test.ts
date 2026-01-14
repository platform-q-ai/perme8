import { describe, test, expect } from 'vitest'
import { UserColor } from '../../../domain/value-objects/user-color'

describe('UserColor', () => {
  describe('constructor', () => {
    test('creates UserColor with valid hex string', () => {
      const color = new UserColor('#FF6B6B')

      expect(color.hex).toBe('#FF6B6B')
    })

    test('creates UserColor with lowercase hex', () => {
      const color = new UserColor('#ff6b6b')

      expect(color.hex).toBe('#FF6B6B')
    })

    test('throws error for empty string', () => {
      expect(() => new UserColor('')).toThrow('Invalid hex color')
    })

    test('throws error for invalid hex format without hash', () => {
      expect(() => new UserColor('FF6B6B')).toThrow('Invalid hex color')
    })

    test('throws error for invalid hex format with wrong length', () => {
      expect(() => new UserColor('#FF6B6')).toThrow('Invalid hex color')
    })

    test('throws error for invalid hex characters', () => {
      expect(() => new UserColor('#GGGGGG')).toThrow('Invalid hex color')
    })

    test('throws error for null', () => {
      expect(() => new UserColor(null as any)).toThrow('Invalid hex color')
    })

    test('throws error for undefined', () => {
      expect(() => new UserColor(undefined as any)).toThrow('Invalid hex color')
    })

    test('accepts 3-character hex shorthand', () => {
      const color = new UserColor('#F00')

      expect(color.hex).toBe('#F00')
    })
  })

  describe('toRgb', () => {
    test('converts 6-char hex to RGB object', () => {
      const color = new UserColor('#FF6B6B')

      const rgb = color.toRgb()

      expect(rgb.r).toBe(255)
      expect(rgb.g).toBe(107)
      expect(rgb.b).toBe(107)
    })

    test('converts 3-char hex to RGB object', () => {
      const color = new UserColor('#F00')

      const rgb = color.toRgb()

      expect(rgb.r).toBe(255)
      expect(rgb.g).toBe(0)
      expect(rgb.b).toBe(0)
    })

    test('converts black to RGB', () => {
      const color = new UserColor('#000000')

      const rgb = color.toRgb()

      expect(rgb.r).toBe(0)
      expect(rgb.g).toBe(0)
      expect(rgb.b).toBe(0)
    })

    test('converts white to RGB', () => {
      const color = new UserColor('#FFFFFF')

      const rgb = color.toRgb()

      expect(rgb.r).toBe(255)
      expect(rgb.g).toBe(255)
      expect(rgb.b).toBe(255)
    })
  })

  describe('toRgbString', () => {
    test('returns RGB string format', () => {
      const color = new UserColor('#FF6B6B')

      expect(color.toRgbString()).toBe('rgb(255, 107, 107)')
    })

    test('returns RGB string for black', () => {
      const color = new UserColor('#000000')

      expect(color.toRgbString()).toBe('rgb(0, 0, 0)')
    })
  })

  describe('equals', () => {
    test('returns true for same hex value', () => {
      const color1 = new UserColor('#FF6B6B')
      const color2 = new UserColor('#FF6B6B')

      expect(color1.equals(color2)).toBe(true)
    })

    test('returns true for same color in different case', () => {
      const color1 = new UserColor('#FF6B6B')
      const color2 = new UserColor('#ff6b6b')

      expect(color1.equals(color2)).toBe(true)
    })

    test('returns false for different colors', () => {
      const color1 = new UserColor('#FF6B6B')
      const color2 = new UserColor('#4ECDC4')

      expect(color1.equals(color2)).toBe(false)
    })

    test('returns true when compared with itself', () => {
      const color = new UserColor('#FF6B6B')

      expect(color.equals(color)).toBe(true)
    })
  })

  describe('toString', () => {
    test('returns the hex value', () => {
      const color = new UserColor('#FF6B6B')

      expect(color.toString()).toBe('#FF6B6B')
    })
  })

  describe('immutability', () => {
    test('creates a new instance with same value when accessed', () => {
      const color = new UserColor('#FF6B6B')

      // Value is immutable - TypeScript prevents modification at compile time
      expect(color.hex).toBe('#FF6B6B')

      // Creating a new instance doesn't affect the original
      const color2 = new UserColor('#4ECDC4')
      expect(color.hex).toBe('#FF6B6B')
      expect(color2.hex).toBe('#4ECDC4')
    })
  })
})
