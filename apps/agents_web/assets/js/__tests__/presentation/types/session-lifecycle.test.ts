import { describe, expect, test } from 'vitest'

import {
  ACTIVE_STATES,
  ALL_LIFECYCLE_STATES,
  TERMINAL_STATES,
  displayName,
  isActive,
  isTerminal,
} from '../../../presentation/types/session-lifecycle'

describe('session-lifecycle type exports', () => {
  test('exports all lifecycle states with expected counts', () => {
    expect(ALL_LIFECYCLE_STATES).toHaveLength(11)
    expect(ACTIVE_STATES).toHaveLength(7)
    expect(TERMINAL_STATES).toHaveLength(3)
  })

  test('isActive returns true only for active lifecycle states', () => {
    for (const state of ACTIVE_STATES) {
      expect(isActive(state)).toBe(true)
    }

    expect(isActive('idle')).toBe(false)
    for (const state of TERMINAL_STATES) {
      expect(isActive(state)).toBe(false)
    }
  })

  test('isTerminal returns true only for terminal lifecycle states', () => {
    for (const state of TERMINAL_STATES) {
      expect(isTerminal(state)).toBe(true)
    }

    expect(isTerminal('idle')).toBe(false)
    for (const state of ACTIVE_STATES) {
      expect(isTerminal(state)).toBe(false)
    }
  })

  test('displayName returns expected labels for all lifecycle states', () => {
    expect(displayName('idle')).toBe('Idle')
    expect(displayName('queued_cold')).toBe('Queued (cold)')
    expect(displayName('queued_warm')).toBe('Queued (warm)')
    expect(displayName('warming')).toBe('Warming up')
    expect(displayName('pending')).toBe('Pending')
    expect(displayName('starting')).toBe('Starting')
    expect(displayName('running')).toBe('Running')
    expect(displayName('awaiting_feedback')).toBe('Awaiting feedback')
    expect(displayName('completed')).toBe('Completed')
    expect(displayName('failed')).toBe('Failed')
    expect(displayName('cancelled')).toBe('Cancelled')
  })

  test('active and terminal states are subsets of all lifecycle states', () => {
    for (const state of ACTIVE_STATES) {
      expect(ALL_LIFECYCLE_STATES).toContain(state)
    }

    for (const state of TERMINAL_STATES) {
      expect(ALL_LIFECYCLE_STATES).toContain(state)
    }
  })
})
