import { ViewHook } from 'phoenix_live_view'

type OptimisticQueueEntry = {
  id: string
  content: string
  queued_at?: string
  correlation_key?: string
  status?: string
}

type OptimisticQueuePayload = {
  user_id?: string
  task_id?: string | null
  entries?: OptimisticQueueEntry[]
}

type OptimisticNewSessionEntry = {
  id: string
  instruction: string
  image?: string
  queued_at?: string
  status?: string
}

type OptimisticNewSessionsPayload = {
  user_id?: string
  entries?: OptimisticNewSessionEntry[]
}

export class SessionOptimisticStateHook extends ViewHook<HTMLElement> {
  private readonly STORAGE_PREFIX = 'agents:sessions:optimistic:v1'
  private readonly NEW_SESSIONS_STORAGE_PREFIX = 'agents:sessions:optimistic:new:v1'
  private lastHydratedKey: string | null = null
  private lastHydratedNewSessionsKey: string | null = null

  mounted(): void {
    this.handleEvent('optimistic_queue_set', (payload: OptimisticQueuePayload) => {
      this.persist(payload)
    })

    this.handleEvent('optimistic_queue_clear', (payload: OptimisticQueuePayload) => {
      this.clear(payload)
    })

    this.handleEvent('optimistic_new_sessions_set', (payload: OptimisticNewSessionsPayload) => {
      this.persistNewSessions(payload)
    })

    this.hydrateFromStorage()
    this.hydrateNewSessionsFromStorage()
  }

  updated(): void {
    this.hydrateFromStorage()
    this.hydrateNewSessionsFromStorage()
  }

  private hydrateFromStorage(): void {
    const userId = this.el.dataset.userId
    const taskId = this.el.dataset.taskId

    if (!userId || !taskId) {
      this.lastHydratedKey = null
      return
    }

    const key = this.storageKey(userId, taskId)
    if (this.lastHydratedKey === key) {
      return
    }

    this.lastHydratedKey = key
    const raw = localStorage.getItem(key)
    if (!raw) {
      return
    }

    try {
      const parsed = JSON.parse(raw) as { entries?: OptimisticQueueEntry[] }
      const entries = Array.isArray(parsed.entries) ? parsed.entries : []

      if (entries.length > 0) {
        this.pushEvent('hydrate_optimistic_queue', {
          task_id: taskId,
          entries
        })
      }
    } catch {
      localStorage.removeItem(key)
    }
  }

  private persist(payload: OptimisticQueuePayload): void {
    const userId = payload.user_id || this.el.dataset.userId
    const taskId = payload.task_id || this.el.dataset.taskId

    if (!userId || !taskId) {
      return
    }

    const entries = Array.isArray(payload.entries) ? payload.entries : []
    const key = this.storageKey(userId, taskId)

    if (entries.length === 0) {
      localStorage.removeItem(key)
      return
    }

    localStorage.setItem(key, JSON.stringify({ version: 1, entries }))
  }

  private hydrateNewSessionsFromStorage(): void {
    const userId = this.el.dataset.userId

    if (!userId) {
      this.lastHydratedNewSessionsKey = null
      return
    }

    const key = this.newSessionsStorageKey(userId)

    if (this.lastHydratedNewSessionsKey === key) {
      return
    }

    this.lastHydratedNewSessionsKey = key
    const raw = localStorage.getItem(key)

    if (!raw) {
      return
    }

    try {
      const parsed = JSON.parse(raw) as { entries?: OptimisticNewSessionEntry[] }
      const entries = Array.isArray(parsed.entries) ? parsed.entries : []

      if (entries.length > 0) {
        this.pushEvent('hydrate_optimistic_new_sessions', { entries })
      }
    } catch {
      localStorage.removeItem(key)
    }
  }

  private persistNewSessions(payload: OptimisticNewSessionsPayload): void {
    const userId = payload.user_id || this.el.dataset.userId

    if (!userId) {
      return
    }

    const entries = Array.isArray(payload.entries) ? payload.entries : []
    const key = this.newSessionsStorageKey(userId)

    if (entries.length === 0) {
      localStorage.removeItem(key)
      return
    }

    localStorage.setItem(key, JSON.stringify({ version: 1, entries }))
  }

  private clear(payload: OptimisticQueuePayload): void {
    const userId = payload.user_id || this.el.dataset.userId
    const taskId = payload.task_id || this.el.dataset.taskId

    if (!userId || !taskId) {
      return
    }

    localStorage.removeItem(this.storageKey(userId, taskId))
  }

  private storageKey(userId: string, taskId: string): string {
    return `${this.STORAGE_PREFIX}:${userId}:${taskId}`
  }

  private newSessionsStorageKey(userId: string): string {
    return `${this.NEW_SESSIONS_STORAGE_PREFIX}:${userId}`
  }
}
