/**
 * SessionFormHook - Presentation Layer
 *
 * Handles keyboard submit behavior for the session instruction textarea.
 * Enter submits the form, Shift+Enter inserts a newline.
 *
 * NO business logic - only DOM event interception for keyboard shortcuts.
 *
 * @module presentation/hooks
 */

import { ViewHook } from 'phoenix_live_view'

/**
 * Phoenix hook for session form keyboard submit
 *
 * Attaches to the textarea element and intercepts keydown events:
 * - Enter (without Shift): prevents default newline, submits the parent form
 * - Shift+Enter: allows default behavior (inserts newline)
 *
 * @example
 * ```heex
 * <textarea
 *   id="session-instruction"
 *   phx-hook="SessionForm"
 * />
 * ```
 */
/** TTL in milliseconds for draft persistence (24 hours — drafts are user-authored text). */
const DRAFT_STALE_TTL_MS = 24 * 60 * 60 * 1000

type DraftEntry = {
  text: string
  savedAt: number
}

/**
 * Returns true if a draft entry is stale (older than the TTL).
 * Exported for testability.
 */
export function isStaleDraft(
  entry: DraftEntry | null,
  ttlMs: number = DRAFT_STALE_TTL_MS
): boolean {
  if (!entry || !entry.savedAt) return true
  return Date.now() - entry.savedAt > ttlMs
}

export class SessionFormHook extends ViewHook<HTMLTextAreaElement> {
  private handleKeydown?: (e: KeyboardEvent) => void
  private handleInput?: () => void
  private handleSubmit?: () => void
  private storageKey = ''

  private buildStorageKey(): string {
    const scopedKey = this.el.dataset.draftKey || this.el.id || 'session-form'
    return `sessions:draft:${scopedKey}`
  }

  private readDraft(): string {
    if (!this.storageKey) return ''

    try {
      const raw = localStorage.getItem(this.storageKey)
      if (!raw) return ''

      // Try new format with timestamp
      try {
        const parsed = JSON.parse(raw) as DraftEntry
        if (parsed.text !== undefined && parsed.savedAt !== undefined) {
          if (isStaleDraft(parsed)) {
            localStorage.removeItem(this.storageKey)
            return ''
          }
          return parsed.text
        }
      } catch {
        // Not JSON — treat as legacy plain string format
      }

      // Legacy format: plain string (no TTL check, migrate on next write)
      return raw
    } catch {
      return ''
    }
  }

  private writeDraft(value: string): void {
    if (!this.storageKey) return

    try {
      if (value.trim() === '') {
        localStorage.removeItem(this.storageKey)
      } else {
        const entry: DraftEntry = { text: value, savedAt: Date.now() }
        localStorage.setItem(this.storageKey, JSON.stringify(entry))
      }
    } catch {
      // ignore storage errors
    }
  }

  private restoreDraft(): void {
    const existingValue = this.el.value || ''
    if (existingValue.trim() !== '') return

    const draft = this.readDraft()
    if (draft.trim() === '') return

    this.el.value = draft
  }

  private clearDraft(): void {
    if (!this.storageKey) return

    try {
      localStorage.removeItem(this.storageKey)
    } catch {
      // ignore storage errors
    }
  }

  /**
   * Phoenix hook lifecycle: mounted
   * Sets up keydown listener for Enter-to-submit behavior
   */
  mounted(): void {
    this.storageKey = this.buildStorageKey()
    this.restoreDraft()

    this.handleKeydown = (e: KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        const form = this.el.closest('form')
        if (form) {
          form.dispatchEvent(
            new Event('submit', { bubbles: true, cancelable: true })
          )
        }
      }
    }
    this.el.addEventListener('keydown', this.handleKeydown)

    this.handleInput = () => {
      this.writeDraft(this.el.value)
    }
    this.el.addEventListener('input', this.handleInput)

    const form = this.el.closest('form')
    if (form) {
      this.handleSubmit = () => {
        window.requestAnimationFrame(() => {
          this.clearDraft()
          this.el.value = ''
        })
      }
      form.addEventListener('submit', this.handleSubmit)
    }

    // Server can push "focus_input" to grab focus (e.g. on session switch)
    this.handleEvent('focus_input', () => {
      this.el.focus()
    })

    // Server can push "restore_draft" to restore an instruction
    // (e.g. when a session is paused/cancelled)
    this.handleEvent('restore_draft', ({ text }: { text: string }) => {
      if (text) {
        this.el.value = text
        this.writeDraft(text)
        this.el.focus()
      }
    })

    // Server can push "clear_input" to clear the textarea and draft
    // (e.g. on session switch, successful task creation — works despite phx-update="ignore")
    this.handleEvent('clear_input', () => {
      this.el.value = ''
      this.clearDraft()
    })

    // Auto-focus on mount
    this.el.focus()
  }

  updated(): void {
    const nextKey = this.buildStorageKey()
    if (nextKey !== this.storageKey) {
      this.storageKey = nextKey
    }

    this.restoreDraft()
  }

  /**
   * Phoenix hook lifecycle: destroyed
   * Cleanup keydown event listener
   */
  destroyed(): void {
    if (this.handleKeydown) {
      this.el.removeEventListener('keydown', this.handleKeydown)
    }

    if (this.handleInput) {
      this.el.removeEventListener('input', this.handleInput)
    }

    const form = this.el.closest('form')
    if (form && this.handleSubmit) {
      form.removeEventListener('submit', this.handleSubmit)
    }
  }
}
