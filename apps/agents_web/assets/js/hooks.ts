/**
 * Hooks Entry Point for AgentsWeb
 *
 * Phoenix LiveView hooks for the agents web application.
 */

import { SessionLogHook } from './presentation/hooks/session-log-hook'
import { SessionFormHook } from './presentation/hooks/session-form-hook'
import { ConcurrencyLimitHook } from './presentation/hooks/concurrency-limit-hook'

export {
  SessionLogHook as SessionLog,
  SessionFormHook as SessionForm,
  ConcurrencyLimitHook as ConcurrencyLimit
}

export default {
  SessionLog: SessionLogHook,
  SessionForm: SessionFormHook,
  ConcurrencyLimit: ConcurrencyLimitHook
}
