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
      return localStorage.getItem(this.storageKey) || ''
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
        localStorage.setItem(this.storageKey, value)
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
