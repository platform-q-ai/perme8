/**
 * ChatPanelHook - Phoenix Hook for Chat Panel Drawer State
 *
 * Thin Phoenix hook that handles responsive panel state, keyboard shortcuts,
 * and window resize behavior. NO business logic - only UI state management.
 *
 * Responsibilities:
 * - Handle responsive panel state (desktop: open by default, mobile: closed)
 * - Handle keyboard shortcuts (Cmd/Ctrl+K to toggle, Escape to close)
 * - Handle window resize (adjust panel state on breakpoint crossing)
 * - Update toggle button visibility based on panel state
 * - Focus input when panel opens
 *
 * This hook does NOT delegate to use cases - it's pure UI state management.
 *
 * @module presentation/hooks
 */

import { ViewHook } from 'phoenix_live_view'

/**
 * Phoenix hook for chat panel drawer state management
 *
 * Attaches to the chat panel checkbox element and manages:
 * - Responsive defaults (desktop open, mobile closed)
 * - Keyboard shortcuts for accessibility
 * - Auto-adjustment on window resize
 * - Toggle button visibility
 * - Input focus on panel open
 *
 * @example
 * ```heex
 * <input
 *   type="checkbox"
 *   id="chat-panel-checkbox"
 *   phx-hook="ChatPanel"
 * />
 * ```
 */
export class ChatPanelHook extends ViewHook<HTMLInputElement> {
  updated = (): void => {
    // Optional lifecycle hook - called when element attributes change
  }

  private handleKeyboard?: (e: KeyboardEvent) => void
  private handleResize?: () => void
  private handleChange?: () => void
  private handleClick?: () => void
  private handleResizeMouseDown?: (e: MouseEvent) => void
  private handleResizeMouseMove?: (e: MouseEvent) => void
  private handleResizeMouseUp?: () => void
  private toggleBtn: HTMLButtonElement | null = null
  private resizeHandle: HTMLElement | null = null
  private panelContent: HTMLElement | null = null
  private userInteracted = false
  private isResizing = false
  private startX = 0
  private startWidth = 0
  private readonly DESKTOP_BREAKPOINT = 1024
  private readonly STORAGE_KEY = 'chat-panel-open'
  private readonly WIDTH_STORAGE_KEY = 'chat-panel-width'
  private readonly MIN_WIDTH = 384 // w-96
  private readonly MAX_WIDTH_PERCENT = 0.8

  /**
   * Phoenix hook lifecycle: mounted
   * Called when the element is added to the DOM
   */
  mounted(): void {
    this.toggleBtn = document.getElementById('chat-toggle-btn') as HTMLButtonElement | null
    this.userInteracted = false

    // Restore state from localStorage, or use responsive default
    const savedState = localStorage.getItem(this.STORAGE_KEY)
    if (savedState !== null) {
      this.el.checked = savedState === 'true'
      this.userInteracted = true // Treat restored state as user preference
    } else if (this.isDesktop()) {
      this.el.checked = true
    } else {
      this.el.checked = false
    }

    // Initial button visibility
    this.updateButtonVisibility()

    // Watch for checkbox changes
    this.handleChange = () => {
      this.updateButtonVisibility()

      if (this.el.checked) {
        // Panel is opening - focus the input after animation
        setTimeout(() => {
          const input = document.getElementById('chat-input')
          if (input) {
            input.focus()
          }
        }, 150)
      }
    }
    this.el.addEventListener('change', this.handleChange)

    // Mark as user interaction on click and save state
    this.handleClick = () => {
      this.userInteracted = true
      // Save state after click toggles the checkbox
      setTimeout(() => {
        localStorage.setItem(this.STORAGE_KEY, String(this.el.checked))
      }, 0)
    }
    this.el.addEventListener('click', this.handleClick)

    // Handle window resize
    this.handleResize = () => {
      // Only auto-adjust if user hasn't manually toggled
      if (!this.userInteracted) {
        const shouldBeOpen = this.isDesktop()
        if (this.el.checked !== shouldBeOpen) {
          this.el.checked = shouldBeOpen
          this.updateButtonVisibility()
        }
      }
    }
    window.addEventListener('resize', this.handleResize)

    // Keyboard shortcuts
    this.handleKeyboard = (e: KeyboardEvent) => {
      // Cmd/Ctrl + K to toggle
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        this.userInteracted = true
        this.el.click()
      }

      // Escape to close
      if (e.key === 'Escape' && this.el.checked) {
        this.userInteracted = true
        this.el.click()
      }
    }
    document.addEventListener('keydown', this.handleKeyboard)

    // Set updated lifecycle method
    this.updated = () => {
      this.updateButtonVisibility()
    }

    // Setup resize handle
    this.resizeHandle = document.getElementById('chat-panel-resize-handle')
    this.panelContent = document.getElementById('chat-panel-content')

    // Restore saved width
    const savedWidth = localStorage.getItem(this.WIDTH_STORAGE_KEY)
    if (savedWidth && this.panelContent) {
      this.panelContent.style.width = `${savedWidth}px`
    }

    if (this.resizeHandle) {
      this.handleResizeMouseDown = (e: MouseEvent) => {
        e.preventDefault()
        this.isResizing = true
        this.startX = e.clientX
        this.startWidth = this.panelContent?.offsetWidth ?? this.MIN_WIDTH
        document.body.style.cursor = 'col-resize'
        document.body.style.userSelect = 'none'
      }
      this.resizeHandle.addEventListener('mousedown', this.handleResizeMouseDown)

      this.handleResizeMouseMove = (e: MouseEvent) => {
        if (!this.isResizing || !this.panelContent) return

        // Calculate new width (dragging left increases width)
        const delta = this.startX - e.clientX
        let newWidth = this.startWidth + delta

        // Enforce min/max constraints
        const maxWidth = window.innerWidth * this.MAX_WIDTH_PERCENT
        newWidth = Math.max(this.MIN_WIDTH, Math.min(maxWidth, newWidth))

        this.panelContent.style.width = `${newWidth}px`
      }
      document.addEventListener('mousemove', this.handleResizeMouseMove)

      this.handleResizeMouseUp = () => {
        if (this.isResizing && this.panelContent) {
          // Save width to localStorage
          localStorage.setItem(this.WIDTH_STORAGE_KEY, String(this.panelContent.offsetWidth))
        }
        this.isResizing = false
        document.body.style.cursor = ''
        document.body.style.userSelect = ''
      }
      document.addEventListener('mouseup', this.handleResizeMouseUp)
    }
  }

  /**
   * Phoenix hook lifecycle: destroyed
   * Called when the element is removed from the DOM
   */
  destroyed(): void {
    if (this.handleKeyboard) {
      document.removeEventListener('keydown', this.handleKeyboard)
    }
    if (this.handleResize) {
      window.removeEventListener('resize', this.handleResize)
    }
    if (this.handleChange) {
      this.el.removeEventListener('change', this.handleChange)
    }
    if (this.handleClick) {
      this.el.removeEventListener('click', this.handleClick)
    }
    if (this.handleResizeMouseDown && this.resizeHandle) {
      this.resizeHandle.removeEventListener('mousedown', this.handleResizeMouseDown)
    }
    if (this.handleResizeMouseMove) {
      document.removeEventListener('mousemove', this.handleResizeMouseMove)
    }
    if (this.handleResizeMouseUp) {
      document.removeEventListener('mouseup', this.handleResizeMouseUp)
    }
  }

  /**
   * Checks if the current viewport is desktop size
   */
  private isDesktop(): boolean {
    return window.innerWidth >= this.DESKTOP_BREAKPOINT
  }

  /**
   * Updates toggle button visibility based on panel state
   * - Panel open: hide button
   * - Panel closed: show button
   */
  private updateButtonVisibility(): void {
    // Re-query toggle button if not found initially
    if (!this.toggleBtn) {
      this.toggleBtn = document.getElementById('chat-toggle-btn') as HTMLButtonElement | null
    }

    if (this.toggleBtn) {
      if (this.el.checked) {
        this.toggleBtn.classList.add('hidden')
      } else {
        this.toggleBtn.classList.remove('hidden')
      }
    }
  }
}
