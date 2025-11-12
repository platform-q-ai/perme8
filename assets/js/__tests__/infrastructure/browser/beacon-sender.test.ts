import { describe, test, expect, beforeEach, vi } from 'vitest'
import { BeaconSender } from '../../../infrastructure/browser/beacon-sender'

describe('BeaconSender', () => {
  let sender: BeaconSender
  let mockSendBeacon: ReturnType<typeof vi.fn>

  beforeEach(() => {
    mockSendBeacon = vi.fn()

    // Mock navigator.sendBeacon
    global.navigator = {
      sendBeacon: mockSendBeacon
    } as any

    sender = new BeaconSender()
  })

  describe('isBeaconSupported', () => {
    test('returns true when sendBeacon is available', () => {
      const result = sender.isBeaconSupported()

      expect(result).toBe(true)
    })

    test('returns false when sendBeacon is not available', () => {
      global.navigator.sendBeacon = undefined as any

      const result = sender.isBeaconSupported()

      expect(result).toBe(false)
    })

    test('returns false when navigator is not available', () => {
      const originalNavigator = global.navigator
      delete (global as any).navigator

      const result = sender.isBeaconSupported()

      expect(result).toBe(false)

      // Restore navigator
      global.navigator = originalNavigator
    })
  })

  describe('send', () => {
    test('sends data using beacon when supported', () => {
      mockSendBeacon.mockReturnValue(true)

      const result = sender.send('https://example.com/api', { key: 'value' })

      expect(result).toBe(true)
      expect(mockSendBeacon).toHaveBeenCalledWith(
        'https://example.com/api',
        expect.any(Blob)
      )
    })

    test('sends JSON blob with correct content type', () => {
      mockSendBeacon.mockReturnValue(true)

      sender.send('https://example.com/api', { key: 'value' })

      const callArgs = mockSendBeacon.mock.calls[0]
      const blob = callArgs[1] as Blob
      expect(blob.type).toBe('application/json')
    })

    test('serializes data to JSON in blob', async () => {
      mockSendBeacon.mockReturnValue(true)
      const data = { key: 'value', number: 42 }

      sender.send('https://example.com/api', data)

      const callArgs = mockSendBeacon.mock.calls[0]
      const blob = callArgs[1] as Blob
      const text = await blob.text()
      expect(JSON.parse(text)).toEqual(data)
    })

    test('returns false when beacon fails', () => {
      mockSendBeacon.mockReturnValue(false)

      const result = sender.send('https://example.com/api', { key: 'value' })

      expect(result).toBe(false)
    })

    test('returns false when beacon is not supported', () => {
      global.navigator.sendBeacon = undefined as any

      const result = sender.send('https://example.com/api', { key: 'value' })

      expect(result).toBe(false)
    })

    test('handles empty data object', () => {
      mockSendBeacon.mockReturnValue(true)

      const result = sender.send('https://example.com/api', {})

      expect(result).toBe(true)
      expect(mockSendBeacon).toHaveBeenCalled()
    })

    test('handles complex nested data', async () => {
      mockSendBeacon.mockReturnValue(true)
      const data = {
        user: { id: 1, name: 'Test' },
        items: [1, 2, 3],
        metadata: { timestamp: Date.now() }
      }

      sender.send('https://example.com/api', data)

      const callArgs = mockSendBeacon.mock.calls[0]
      const blob = callArgs[1] as Blob
      const text = await blob.text()
      expect(JSON.parse(text)).toEqual(data)
    })

    test('handles special characters in data', async () => {
      mockSendBeacon.mockReturnValue(true)
      const data = { message: 'Hello "world" with \n newlines & special chars: 日本語' }

      sender.send('https://example.com/api', data)

      const callArgs = mockSendBeacon.mock.calls[0]
      const blob = callArgs[1] as Blob
      const text = await blob.text()
      expect(JSON.parse(text)).toEqual(data)
    })

    test('handles beacon throwing error', () => {
      mockSendBeacon.mockImplementation(() => {
        throw new Error('Network error')
      })

      const result = sender.send('https://example.com/api', { key: 'value' })

      expect(result).toBe(false)
    })

    test('handles long URLs', () => {
      mockSendBeacon.mockReturnValue(true)
      const longUrl = 'https://example.com/api?' + 'x='.repeat(100)

      const result = sender.send(longUrl, { key: 'value' })

      expect(result).toBe(true)
      expect(mockSendBeacon).toHaveBeenCalledWith(longUrl, expect.any(Blob))
    })

    test('handles large data payloads', () => {
      mockSendBeacon.mockReturnValue(true)
      const largeData = { items: Array(1000).fill({ id: 1, value: 'test' }) }

      const result = sender.send('https://example.com/api', largeData)

      expect(result).toBe(true)
    })
  })
})
