import { describe, test, expect } from 'vitest'
import { Selection } from '../../../domain/value-objects/selection'

describe('Selection', () => {
  describe('constructor', () => {
    test('creates Selection with valid positions', () => {
      const selection = new Selection(0, 10)

      expect(selection.anchor).toBe(0)
      expect(selection.head).toBe(10)
    })

    test('creates Selection with same anchor and head (collapsed)', () => {
      const selection = new Selection(5, 5)

      expect(selection.anchor).toBe(5)
      expect(selection.head).toBe(5)
    })

    test('throws error for negative anchor', () => {
      expect(() => new Selection(-1, 10)).toThrow('Selection positions must be non-negative')
    })

    test('throws error for negative head', () => {
      expect(() => new Selection(0, -5)).toThrow('Selection positions must be non-negative')
    })

    test('throws error for both negative positions', () => {
      expect(() => new Selection(-1, -5)).toThrow('Selection positions must be non-negative')
    })

    test('allows zero positions', () => {
      const selection = new Selection(0, 0)

      expect(selection.anchor).toBe(0)
      expect(selection.head).toBe(0)
    })
  })

  describe('isEmpty', () => {
    test('returns true when anchor equals head', () => {
      const selection = new Selection(5, 5)

      expect(selection.isEmpty()).toBe(true)
    })

    test('returns false when anchor differs from head', () => {
      const selection = new Selection(5, 10)

      expect(selection.isEmpty()).toBe(false)
    })

    test('returns true for zero-position collapsed selection', () => {
      const selection = new Selection(0, 0)

      expect(selection.isEmpty()).toBe(true)
    })
  })

  describe('isForward', () => {
    test('returns true when anchor is less than head', () => {
      const selection = new Selection(5, 10)

      expect(selection.isForward()).toBe(true)
    })

    test('returns false when anchor is greater than head', () => {
      const selection = new Selection(10, 5)

      expect(selection.isForward()).toBe(false)
    })

    test('returns false when selection is collapsed', () => {
      const selection = new Selection(5, 5)

      expect(selection.isForward()).toBe(false)
    })
  })

  describe('isBackward', () => {
    test('returns true when anchor is greater than head', () => {
      const selection = new Selection(10, 5)

      expect(selection.isBackward()).toBe(true)
    })

    test('returns false when anchor is less than head', () => {
      const selection = new Selection(5, 10)

      expect(selection.isBackward()).toBe(false)
    })

    test('returns false when selection is collapsed', () => {
      const selection = new Selection(5, 5)

      expect(selection.isBackward()).toBe(false)
    })
  })

  describe('getStart', () => {
    test('returns anchor when anchor is less than head', () => {
      const selection = new Selection(5, 10)

      expect(selection.getStart()).toBe(5)
    })

    test('returns head when head is less than anchor', () => {
      const selection = new Selection(10, 5)

      expect(selection.getStart()).toBe(5)
    })

    test('returns anchor when selection is collapsed', () => {
      const selection = new Selection(7, 7)

      expect(selection.getStart()).toBe(7)
    })
  })

  describe('getEnd', () => {
    test('returns head when anchor is less than head', () => {
      const selection = new Selection(5, 10)

      expect(selection.getEnd()).toBe(10)
    })

    test('returns anchor when head is less than anchor', () => {
      const selection = new Selection(10, 5)

      expect(selection.getEnd()).toBe(10)
    })

    test('returns head when selection is collapsed', () => {
      const selection = new Selection(7, 7)

      expect(selection.getEnd()).toBe(7)
    })
  })

  describe('getLength', () => {
    test('returns length for forward selection', () => {
      const selection = new Selection(5, 10)

      expect(selection.getLength()).toBe(5)
    })

    test('returns length for backward selection', () => {
      const selection = new Selection(10, 5)

      expect(selection.getLength()).toBe(5)
    })

    test('returns zero for collapsed selection', () => {
      const selection = new Selection(5, 5)

      expect(selection.getLength()).toBe(0)
    })

    test('returns correct length for large range', () => {
      const selection = new Selection(100, 500)

      expect(selection.getLength()).toBe(400)
    })
  })

  describe('contains', () => {
    test('returns true for position within forward selection', () => {
      const selection = new Selection(5, 10)

      expect(selection.contains(7)).toBe(true)
    })

    test('returns true for position within backward selection', () => {
      const selection = new Selection(10, 5)

      expect(selection.contains(7)).toBe(true)
    })

    test('returns true for start position', () => {
      const selection = new Selection(5, 10)

      expect(selection.contains(5)).toBe(true)
    })

    test('returns true for end position', () => {
      const selection = new Selection(5, 10)

      expect(selection.contains(10)).toBe(true)
    })

    test('returns false for position before selection', () => {
      const selection = new Selection(5, 10)

      expect(selection.contains(3)).toBe(false)
    })

    test('returns false for position after selection', () => {
      const selection = new Selection(5, 10)

      expect(selection.contains(15)).toBe(false)
    })

    test('returns true for collapsed selection at exact position', () => {
      const selection = new Selection(5, 5)

      expect(selection.contains(5)).toBe(true)
    })

    test('returns false for collapsed selection at different position', () => {
      const selection = new Selection(5, 5)

      expect(selection.contains(6)).toBe(false)
    })
  })

  describe('equals', () => {
    test('returns true for same anchor and head values', () => {
      const sel1 = new Selection(5, 10)
      const sel2 = new Selection(5, 10)

      expect(sel1.equals(sel2)).toBe(true)
    })

    test('returns false for different anchor', () => {
      const sel1 = new Selection(5, 10)
      const sel2 = new Selection(6, 10)

      expect(sel1.equals(sel2)).toBe(false)
    })

    test('returns false for different head', () => {
      const sel1 = new Selection(5, 10)
      const sel2 = new Selection(5, 11)

      expect(sel1.equals(sel2)).toBe(false)
    })

    test('returns true when compared with itself', () => {
      const selection = new Selection(5, 10)

      expect(selection.equals(selection)).toBe(true)
    })

    test('returns true for two collapsed selections at same position', () => {
      const sel1 = new Selection(5, 5)
      const sel2 = new Selection(5, 5)

      expect(sel1.equals(sel2)).toBe(true)
    })
  })

  describe('immutability', () => {
    test('creates immutable value object', () => {
      const selection = new Selection(5, 10)

      // Properties are readonly - TypeScript prevents modification at compile time
      expect(selection.anchor).toBe(5)
      expect(selection.head).toBe(10)

      // Creating a new instance doesn't affect the original
      const selection2 = new Selection(15, 20)
      expect(selection.anchor).toBe(5)
      expect(selection.head).toBe(10)
      expect(selection2.anchor).toBe(15)
      expect(selection2.head).toBe(20)
    })
  })
})
