/** Union of all possible session lifecycle states. */
export type SessionLifecycleState =
  | 'idle'
  | 'queued_cold'
  | 'queued_warm'
  | 'warming'
  | 'pending'
  | 'starting'
  | 'running'
  | 'awaiting_feedback'
  | 'completed'
  | 'failed'
  | 'cancelled'

/** States where the session is actively consuming resources or queued. */
export const ACTIVE_STATES: readonly SessionLifecycleState[] = [
  'queued_cold',
  'queued_warm',
  'warming',
  'pending',
  'starting',
  'running',
  'awaiting_feedback',
] as const

/** States where the session has reached a final outcome. */
export const TERMINAL_STATES: readonly SessionLifecycleState[] = [
  'completed',
  'failed',
  'cancelled',
] as const

/** All valid lifecycle states in display order. */
export const ALL_LIFECYCLE_STATES: readonly SessionLifecycleState[] = [
  'idle',
  'queued_cold',
  'queued_warm',
  'warming',
  'pending',
  'starting',
  'running',
  'awaiting_feedback',
  'completed',
  'failed',
  'cancelled',
] as const

/** Returns true if the given state is an active (non-terminal, non-idle) state. */
export function isActive(state: SessionLifecycleState): boolean {
  return (ACTIVE_STATES as readonly string[]).includes(state)
}

/** Returns true if the given state is a terminal state. */
export function isTerminal(state: SessionLifecycleState): boolean {
  return (TERMINAL_STATES as readonly string[]).includes(state)
}

/** Returns a human-readable display name for a lifecycle state. */
export function displayName(state: SessionLifecycleState): string {
  const names: Record<SessionLifecycleState, string> = {
    idle: 'Idle',
    queued_cold: 'Queued (cold)',
    queued_warm: 'Queued (warm)',
    warming: 'Warming up',
    pending: 'Pending',
    starting: 'Starting',
    running: 'Running',
    awaiting_feedback: 'Awaiting feedback',
    completed: 'Completed',
    failed: 'Failed',
    cancelled: 'Cancelled',
  }

  return names[state]
}
