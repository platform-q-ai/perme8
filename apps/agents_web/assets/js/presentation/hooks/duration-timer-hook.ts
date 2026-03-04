/**
 * DurationTimerHook - Presentation Layer
 *
 * Client-side elapsed time counter for session durations.
 * Reads `data-started-at` (ISO 8601) and optional `data-completed-at` from the element.
 * When the session is still running (no completed_at), ticks every second via
 * requestAnimationFrame — zero server round-trips.
 *
 * When LiveView patches the element (e.g. session completes), `updated()` re-reads
 * the data attributes and stops ticking if completed_at is now set.
 *
 * NO business logic - only DOM manipulation for duration display.
 *
 * @module presentation/hooks
 */

import { ViewHook } from 'phoenix_live_view'

function formatSeconds(seconds: number): string {
  if (seconds < 60) return `${seconds}s`
  if (seconds < 3600) {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m}m ${s}s`
  }
  if (seconds < 86400) {
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    return `${h}h ${m}m`
  }
  const d = Math.floor(seconds / 86400)
  const h = Math.floor((seconds % 86400) / 3600)
  return `${d}d ${h}h`
}

export class DurationTimerHook extends ViewHook {
  private rafId: number | null = null
  private lastRenderedSeconds: number = -1

  mounted(): void {
    this.startTicking()
  }

  updated(): void {
    // LiveView patched the element — re-read attributes and restart/stop as needed
    this.stopTicking()
    this.lastRenderedSeconds = -1
    this.startTicking()
  }

  destroyed(): void {
    this.stopTicking()
  }

  private startTicking(): void {
    const startedAt = this.el.dataset.startedAt
    if (!startedAt) {
      this.el.textContent = ''
      return
    }

    const startMs = new Date(startedAt).getTime()
    const completedAt = this.el.dataset.completedAt

    if (completedAt) {
      // Session is finished — render final duration, no ticking
      const endMs = new Date(completedAt).getTime()
      const seconds = Math.max(0, Math.floor((endMs - startMs) / 1000))
      this.el.textContent = formatSeconds(seconds)
      return
    }

    // Session is running — tick every second via rAF
    const tick = (): void => {
      const now = Date.now()
      const seconds = Math.max(0, Math.floor((now - startMs) / 1000))

      // Only update DOM when the displayed value actually changes
      if (seconds !== this.lastRenderedSeconds) {
        this.lastRenderedSeconds = seconds
        this.el.textContent = formatSeconds(seconds)
      }

      this.rafId = requestAnimationFrame(tick)
    }

    this.rafId = requestAnimationFrame(tick)
  }

  private stopTicking(): void {
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
  }
}
