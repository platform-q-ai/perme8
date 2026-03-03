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

export class SessionOptimisticStateHook extends ViewHook<HTMLElement> {
  private readonly STORAGE_PREFIX = 'agents:sessions:optimistic:v1'
  private lastHydratedKey: string | null = null

  mounted(): void {
    this.handleEvent('optimistic_queue_set', (payload: OptimisticQueuePayload) => {
      this.persist(payload)
    })

    this.handleEvent('optimistic_queue_clear', (payload: OptimisticQueuePayload) => {
      this.clear(payload)
    })

    this.hydrateFromStorage()
  }

  updated(): void {
    this.hydrateFromStorage()
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
}
