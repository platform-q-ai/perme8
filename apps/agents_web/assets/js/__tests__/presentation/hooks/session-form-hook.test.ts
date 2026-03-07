/**
 * Tests for SessionFormHook pure functions (Presentation Layer)
 *
 * Tests the exported utility functions used by the session form hook.
 * Hook lifecycle methods (mounted, destroyed, updated) depend on LiveView's
 * handleEvent mechanism and are tested via BDD browser features.
 */

import { describe, test, expect } from 'vitest'
import { isStaleDraft } from '../../../presentation/hooks/session-form-hook'

describe('isStaleDraft', () => {
  test('returns true for null entry', () => {
    expect(isStaleDraft(null)).toBe(true)
  })

  test('returns true for entry with savedAt of 0', () => {
    expect(isStaleDraft({ text: 'hello', savedAt: 0 })).toBe(true)
  })

  test('returns true for entry older than default TTL (24 hours)', () => {
    const oldTime = Date.now() - 25 * 60 * 60 * 1000 // 25 hours ago
    expect(isStaleDraft({ text: 'hello', savedAt: oldTime })).toBe(true)
  })

  test('returns false for recent entry within default TTL', () => {
    const recentTime = Date.now() - 1000 // 1 second ago
    expect(isStaleDraft({ text: 'hello', savedAt: recentTime })).toBe(false)
  })

  test('returns false for entry just within TTL boundary', () => {
    const withinTtl = Date.now() - 23 * 60 * 60 * 1000 // 23 hours ago
    expect(isStaleDraft({ text: 'hello', savedAt: withinTtl })).toBe(false)
  })

  test('respects custom TTL — stale when older', () => {
    const time = Date.now() - 5000 // 5 seconds ago
    expect(isStaleDraft({ text: 'hello', savedAt: time }, 3000)).toBe(true)
  })

  test('respects custom TTL — fresh when younger', () => {
    const time = Date.now() - 5000 // 5 seconds ago
    expect(isStaleDraft({ text: 'hello', savedAt: time }, 10000)).toBe(false)
  })
})
