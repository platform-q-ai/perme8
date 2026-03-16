/**
 * Tests for SessionFormHook pure functions (Presentation Layer)
 *
 * Tests the exported utility functions used by the session form hook.
 * Hook lifecycle methods (mounted, destroyed, updated) depend on LiveView's
 * handleEvent mechanism and are tested via BDD browser features.
 */

import { describe, test, expect, beforeEach } from 'vitest'
import {
  isStaleDraft,
  buildStorageKeyFromScope,
  switchDraftKey,
} from '../../../presentation/hooks/session-form-hook'

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

describe('buildStorageKeyFromScope', () => {
  test('builds key from ticket scope', () => {
    expect(buildStorageKeyFromScope('ticket:42')).toBe(
      'sessions:draft:ticket:42'
    )
  })

  test('builds key from session scope', () => {
    expect(buildStorageKeyFromScope('session:abc-123')).toBe(
      'sessions:draft:session:abc-123'
    )
  })

  test('falls back to session-form for empty string', () => {
    expect(buildStorageKeyFromScope('')).toBe('sessions:draft:session-form')
  })

  test('falls back to session-form for undefined', () => {
    expect(buildStorageKeyFromScope(undefined)).toBe(
      'sessions:draft:session-form'
    )
  })
})

describe('switchDraftKey', () => {
  let storage: Storage

  beforeEach(() => {
    const store = new Map<string, string>()
    storage = {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => {
        store.set(k, v)
      },
      removeItem: (k: string) => {
        store.delete(k)
      },
      clear: () => store.clear(),
      get length() {
        return store.size
      },
      key: (_i: number) => null,
    }
  })

  test('saves current value under old key and returns draft from new key', () => {
    // Pre-populate new key with a draft
    const draftEntry = JSON.stringify({
      text: 'draft for ticket 99',
      savedAt: Date.now(),
    })
    storage.setItem('sessions:draft:ticket:99', draftEntry)

    const result = switchDraftKey(
      'sessions:draft:ticket:42',
      'sessions:draft:ticket:99',
      'current text for 42',
      storage
    )

    expect(result).toBe('draft for ticket 99')
    // Verify old key was saved
    const saved = JSON.parse(
      storage.getItem('sessions:draft:ticket:42') as string
    )
    expect(saved.text).toBe('current text for 42')
  })

  test('returns empty string when new key has no draft', () => {
    const result = switchDraftKey(
      'sessions:draft:ticket:42',
      'sessions:draft:ticket:99',
      'text for 42',
      storage
    )

    expect(result).toBe('')
  })

  test('returns current value when old and new keys are the same', () => {
    const result = switchDraftKey(
      'sessions:draft:ticket:42',
      'sessions:draft:ticket:42',
      'keep this text',
      storage
    )

    expect(result).toBe('keep this text')
  })

  test('removes old key when current value is empty', () => {
    storage.setItem(
      'sessions:draft:ticket:42',
      JSON.stringify({ text: 'old', savedAt: Date.now() })
    )

    switchDraftKey(
      'sessions:draft:ticket:42',
      'sessions:draft:ticket:99',
      '',
      storage
    )

    expect(storage.getItem('sessions:draft:ticket:42')).toBeNull()
  })

  test('returns empty string when new key has a stale draft', () => {
    const staleEntry = JSON.stringify({
      text: 'stale draft',
      savedAt: Date.now() - 25 * 60 * 60 * 1000, // 25 hours ago
    })
    storage.setItem('sessions:draft:ticket:99', staleEntry)

    const result = switchDraftKey(
      'sessions:draft:ticket:42',
      'sessions:draft:ticket:99',
      'current text',
      storage
    )

    expect(result).toBe('')
    // Stale entry should be cleaned up
    expect(storage.getItem('sessions:draft:ticket:99')).toBeNull()
  })

  test('other ticket drafts are NOT cleared on submit-like empty save', () => {
    storage.setItem(
      'sessions:draft:ticket:99',
      JSON.stringify({ text: 'other ticket draft', savedAt: Date.now() })
    )

    // Switch away from ticket:42 (with empty value, simulating post-submit)
    switchDraftKey(
      'sessions:draft:ticket:42',
      'sessions:draft:ticket:99',
      '',
      storage
    )

    // ticket:99's draft should still be readable
    const raw = storage.getItem('sessions:draft:ticket:99')
    expect(raw).not.toBeNull()
    const parsed = JSON.parse(raw as string)
    expect(parsed.text).toBe('other ticket draft')
  })
})
