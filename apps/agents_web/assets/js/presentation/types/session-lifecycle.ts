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

export const ACTIVE_STATES: readonly SessionLifecycleState[] = [
  'queued_cold',
  'queued_warm',
  'warming',
  'pending',
  'starting',
  'running',
  'awaiting_feedback',
] as const

export const TERMINAL_STATES: readonly SessionLifecycleState[] = [
  'completed',
  'failed',
  'cancelled',
] as const

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

export function isActive(state: SessionLifecycleState): boolean {
  return (ACTIVE_STATES as readonly string[]).includes(state)
}

export function isTerminal(state: SessionLifecycleState): boolean {
  return (TERMINAL_STATES as readonly string[]).includes(state)
}

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
