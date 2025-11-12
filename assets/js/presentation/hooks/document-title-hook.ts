/**
 * DocumentTitleHook - Thin Phoenix LiveView hook for document title input
 *
 * Responsibilities:
 * - Handle Enter key: blur input (trigger autosave) and focus editor
 * - Handle Escape key: blur input (cancel editing)
 * - NO business logic - only DOM event handling and focus management
 *
 * Following presentation layer principles:
 * - Thin hook - only handles Phoenix lifecycle and DOM events
 * - Delegates to DOM APIs for focus/blur
 * - No business logic or validation
 */

import { ViewHook } from 'phoenix_live_view'

export class DocumentTitleHook extends ViewHook<HTMLInputElement> {
  private handleKeyDown?: (event: KeyboardEvent) => void

  mounted(): void {
    this.handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        event.preventDefault()

        // Blur to trigger autosave (LiveView handles the save)
        this.el.blur()

        // Focus editor after blur event processes
        setTimeout(() => {
          const editor = document.querySelector('#editor-container .ProseMirror') as HTMLElement
          if (editor) {
            editor.focus()
          }
        }, 100)
      } else if (event.key === 'Escape') {
        event.preventDefault()

        // Blur without saving (cancel editing)
        this.el.blur()
      }
    }

    this.el.addEventListener('keydown', this.handleKeyDown)
  }

  destroyed(): void {
    if (this.handleKeyDown) {
      this.el.removeEventListener('keydown', this.handleKeyDown)
    }
  }
}
