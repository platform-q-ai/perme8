/**
 * Hooks Entry Point for AgentsWeb
 *
 * Phoenix LiveView hooks for the agents web application.
 */

import { SessionLogHook } from './presentation/hooks/session-log-hook'
import { SessionFormHook } from './presentation/hooks/session-form-hook'
import { SessionOptimisticStateHook } from './presentation/hooks/session-optimistic-state-hook'
import { ConcurrencyLimitHook } from './presentation/hooks/concurrency-limit-hook'
import { WarmCacheLimitHook } from './presentation/hooks/warm-cache-limit-hook'
import { TicketLaneDndHook } from './presentation/hooks/ticket-lane-dnd-hook'

export {
  SessionLogHook as SessionLog,
  SessionFormHook as SessionForm,
  SessionOptimisticStateHook as SessionOptimisticState,
  ConcurrencyLimitHook as ConcurrencyLimit,
  WarmCacheLimitHook as WarmCacheLimit,
  TicketLaneDndHook as TicketLaneDnd
}

export default {
  SessionLog: SessionLogHook,
  SessionForm: SessionFormHook,
  SessionOptimisticState: SessionOptimisticStateHook,
  ConcurrencyLimit: ConcurrencyLimitHook,
  WarmCacheLimit: WarmCacheLimitHook,
  TicketLaneDnd: TicketLaneDndHook
}
