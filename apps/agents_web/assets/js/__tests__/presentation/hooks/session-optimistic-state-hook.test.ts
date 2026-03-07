/**
 * Tests for SessionOptimisticStateHook pure functions (Presentation Layer)
 *
 * Tests the exported utility functions for queued message staleness filtering.
 * Hook lifecycle methods depend on LiveView's handleEvent mechanism and are
 * tested via BDD browser features.
 */

import { describe, test, expect } from 'vitest'
import {
  isStaleQueueEntry,
  filterStaleEntries,
} from '../../../presentation/hooks/session-optimistic-state-hook'

describe('isStaleQueueEntry', () => {
  test('returns true when queued_at is missing', () => {
    expect(isStaleQueueEntry({ id: '1', content: 'msg' })).toBe(true)
  })

  test('returns true when queued_at is invalid date string', () => {
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: 'not-a-date' })).toBe(true)
  })

  test('returns true when entry is older than default TTL (120s)', () => {
    const old = new Date(Date.now() - 150_000).toISOString()
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: old })).toBe(true)
  })

  test('returns false for recent entry within default TTL', () => {
    const recent = new Date(Date.now() - 10_000).toISOString()
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: recent })).toBe(false)
  })

  test('returns false for entry at TTL boundary', () => {
    const boundary = new Date(Date.now() - 119_000).toISOString()
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: boundary })).toBe(false)
  })

  test('respects custom TTL — stale when older', () => {
    const time = new Date(Date.now() - 5000).toISOString()
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: time }, 3000)).toBe(true)
  })

  test('respects custom TTL — fresh when younger', () => {
    const time = new Date(Date.now() - 5000).toISOString()
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: time }, 10000)).toBe(false)
  })
})

describe('filterStaleEntries', () => {
  test('removes stale entries and keeps fresh ones', () => {
    const old = new Date(Date.now() - 150_000).toISOString()
    const recent = new Date(Date.now() - 10_000).toISOString()
    const entries = [
      { id: '1', content: 'old', queued_at: old },
      { id: '2', content: 'new', queued_at: recent },
    ]

    const result = filterStaleEntries(entries)
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe('2')
  })

  test('returns empty array when all entries are stale', () => {
    const old = new Date(Date.now() - 150_000).toISOString()
    const entries = [
      { id: '1', content: 'old1', queued_at: old },
      { id: '2', content: 'old2', queued_at: old },
    ]

    expect(filterStaleEntries(entries)).toHaveLength(0)
  })

  test('returns all entries when none are stale', () => {
    const recent = new Date(Date.now() - 10_000).toISOString()
    const entries = [
      { id: '1', content: 'a', queued_at: recent },
      { id: '2', content: 'b', queued_at: recent },
    ]

    expect(filterStaleEntries(entries)).toHaveLength(2)
  })

  test('handles empty array', () => {
    expect(filterStaleEntries([])).toHaveLength(0)
  })

  test('respects custom TTL', () => {
    const time = new Date(Date.now() - 5000).toISOString()
    const entries = [
      { id: '1', content: 'msg', queued_at: time },
    ]

    expect(filterStaleEntries(entries, 3000)).toHaveLength(0)
    expect(filterStaleEntries(entries, 10000)).toHaveLength(1)
  })
})
