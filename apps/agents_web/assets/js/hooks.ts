/**
 * Hooks Entry Point for AgentsWeb
 *
 * Phoenix LiveView hooks for the agents web application.
 */

import { SessionLogHook } from './presentation/hooks/session-log-hook'
import { SessionFormHook } from './presentation/hooks/session-form-hook'
import { SessionOptimisticStateHook } from './presentation/hooks/session-optimistic-state-hook'
import { TriageLaneDndHook } from './presentation/hooks/triage-lane-dnd-hook'
import { DurationTimerHook } from './presentation/hooks/duration-timer-hook'

export {
  SessionLogHook as SessionLog,
  SessionFormHook as SessionForm,
  SessionOptimisticStateHook as SessionOptimisticState,
  TriageLaneDndHook as TriageLaneDnd,
  DurationTimerHook as DurationTimer
}

export default {
  SessionLog: SessionLogHook,
  SessionForm: SessionFormHook,
  SessionOptimisticState: SessionOptimisticStateHook,
  TriageLaneDnd: TriageLaneDndHook,
  DurationTimer: DurationTimerHook
}
