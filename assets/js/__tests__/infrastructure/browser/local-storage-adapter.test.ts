import { describe, test, expect, beforeEach, vi } from 'vitest'
import { LocalStorageAdapter } from '../../../infrastructure/browser/local-storage-adapter'

describe('LocalStorageAdapter', () => {
  let adapter: LocalStorageAdapter
  let mockStorage: Record<string, string>

  beforeEach(() => {
    // Create mock storage
    mockStorage = {}

    // Mock localStorage
    global.localStorage = {
      getItem: vi.fn((key: string) => mockStorage[key] ?? null),
      setItem: vi.fn((key: string, value: string) => {
        mockStorage[key] = value
      }),
      removeItem: vi.fn((key: string) => {
        delete mockStorage[key]
      }),
      clear: vi.fn(() => {
        mockStorage = {}
      }),
      length: 0,
      key: vi.fn()
    } as any

    adapter = new LocalStorageAdapter()
  })

  describe('get', () => {
    test('returns value for existing key', () => {
      mockStorage['test-key'] = 'test-value'

      const result = adapter.get('test-key')

      expect(result).toBe('test-value')
      expect(localStorage.getItem).toHaveBeenCalledWith('test-key')
    })

    test('returns null for non-existing key', () => {
      const result = adapter.get('non-existing')

      expect(result).toBeNull()
    })

    test('handles localStorage.getItem throwing error', () => {
      vi.mocked(localStorage.getItem).mockImplementation(() => {
        throw new Error('Storage disabled')
      })

      const result = adapter.get('test-key')

      expect(result).toBeNull()
    })
  })

  describe('set', () => {
    test('stores value for key', () => {
      adapter.set('test-key', 'test-value')

      expect(mockStorage['test-key']).toBe('test-value')
      expect(localStorage.setItem).toHaveBeenCalledWith('test-key', 'test-value')
    })

    test('overwrites existing value', () => {
      mockStorage['test-key'] = 'old-value'

      adapter.set('test-key', 'new-value')

      expect(mockStorage['test-key']).toBe('new-value')
    })

    test('handles localStorage.setItem throwing quota exceeded error', () => {
      vi.mocked(localStorage.setItem).mockImplementation(() => {
        const error = new Error('QuotaExceededError')
        error.name = 'QuotaExceededError'
        throw error
      })

      expect(() => adapter.set('test-key', 'value')).not.toThrow()
    })

    test('handles localStorage disabled error', () => {
      vi.mocked(localStorage.setItem).mockImplementation(() => {
        throw new Error('Storage disabled')
      })

      expect(() => adapter.set('test-key', 'value')).not.toThrow()
    })
  })

  describe('remove', () => {
    test('removes existing key', () => {
      mockStorage['test-key'] = 'test-value'

      adapter.remove('test-key')

      expect(mockStorage['test-key']).toBeUndefined()
      expect(localStorage.removeItem).toHaveBeenCalledWith('test-key')
    })

    test('handles removing non-existing key', () => {
      adapter.remove('non-existing')

      expect(localStorage.removeItem).toHaveBeenCalledWith('non-existing')
    })

    test('handles localStorage.removeItem throwing error', () => {
      vi.mocked(localStorage.removeItem).mockImplementation(() => {
        throw new Error('Storage disabled')
      })

      expect(() => adapter.remove('test-key')).not.toThrow()
    })
  })

  describe('clear', () => {
    test('clears all storage', () => {
      mockStorage['key1'] = 'value1'
      mockStorage['key2'] = 'value2'

      adapter.clear()

      expect(localStorage.clear).toHaveBeenCalled()
    })

    test('handles localStorage.clear throwing error', () => {
      vi.mocked(localStorage.clear).mockImplementation(() => {
        throw new Error('Storage disabled')
      })

      expect(() => adapter.clear()).not.toThrow()
    })
  })

  describe('has', () => {
    test('returns true for existing key', () => {
      mockStorage['test-key'] = 'test-value'

      const result = adapter.has('test-key')

      expect(result).toBe(true)
    })

    test('returns false for non-existing key', () => {
      const result = adapter.has('non-existing')

      expect(result).toBe(false)
    })

    test('returns true for key with empty string value', () => {
      mockStorage['empty-key'] = ''

      const result = adapter.has('empty-key')

      expect(result).toBe(true)
    })

    test('handles localStorage.getItem throwing error', () => {
      vi.mocked(localStorage.getItem).mockImplementation(() => {
        throw new Error('Storage disabled')
      })

      const result = adapter.has('test-key')

      expect(result).toBe(false)
    })
  })
})
