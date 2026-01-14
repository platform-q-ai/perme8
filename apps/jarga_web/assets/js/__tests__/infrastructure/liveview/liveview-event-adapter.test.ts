/**
 * LiveViewEventAdapter Tests
 */

import { describe, test, expect, beforeEach, vi } from 'vitest'
import { LiveViewEventAdapter } from '../../../infrastructure/liveview/liveview-event-adapter'

describe('LiveViewEventAdapter', () => {
  let adapter: LiveViewEventAdapter
  let mockPushEvent: ReturnType<typeof vi.fn>
  let mockHandleEvent: ReturnType<typeof vi.fn>

  beforeEach(() => {
    mockPushEvent = vi.fn<(event: string, payload: any) => void>()
    mockHandleEvent = vi.fn<(event: string, callback: (payload: any) => void) => void>()

    adapter = new LiveViewEventAdapter(
      mockPushEvent as (event: string, payload: any) => void,
      mockHandleEvent as (event: string, callback: (payload: any) => void) => void
    )
  })

  describe('pushEvent', () => {
    test('calls pushEvent with correct parameters', () => {
      adapter.pushEvent('test_event', { data: 'test' })

      expect(mockPushEvent).toHaveBeenCalledWith('test_event', { data: 'test' })
    })

    test('works with empty payload', () => {
      adapter.pushEvent('test_event', {})

      expect(mockPushEvent).toHaveBeenCalledWith('test_event', {})
    })
  })

  describe('handleEvent', () => {
    test('registers event handler', () => {
      const callback = vi.fn()

      adapter.handleEvent('test_event', callback)

      expect(mockHandleEvent).toHaveBeenCalledWith('test_event', callback)
    })
  })
})
