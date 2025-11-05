/**
 * JavaScript hooks for the chat panel component
 * Handles localStorage persistence, keyboard shortcuts, and auto-scroll
 */

export const ChatPanel = {
  mounted() {
    // Load collapsed state from localStorage
    const collapsed = localStorage.getItem('chat_collapsed')
    if (collapsed !== null) {
      this.pushEvent('restore_state', { collapsed: collapsed === 'true' })
    }

    // Listen for state changes to save
    this.handleEvent('save_state', ({ collapsed }) => {
      localStorage.setItem('chat_collapsed', collapsed)
    })

    // Keyboard shortcut: Cmd/Ctrl + K to toggle
    this.handleKeyboard = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        this.pushEvent('toggle_panel', {})
      }

      // Escape to close
      if (e.key === 'Escape' && !this.el.dataset.collapsed === 'true') {
        this.pushEvent('toggle_panel', {})
      }
    }

    document.addEventListener('keydown', this.handleKeyboard)
  },

  destroyed() {
    if (this.handleKeyboard) {
      document.removeEventListener('keydown', this.handleKeyboard)
    }
  }
}

export const ChatMessages = {
  mounted() {
    this.scrollToBottom()
  },

  updated() {
    this.scrollToBottom()
  },

  scrollToBottom() {
    // Smooth scroll to bottom
    this.el.scrollTop = this.el.scrollHeight
  }
}

export const ChatInput = {
  mounted() {
    this.el.style.height = 'auto'
    this.el.style.height = this.el.scrollHeight + 'px'

    // Auto-resize on input
    this.el.addEventListener('input', () => {
      this.el.style.height = 'auto'
      this.el.style.height = Math.min(this.el.scrollHeight, 150) + 'px'
    })

    // Submit on Cmd/Ctrl + Enter
    this.el.addEventListener('keydown', (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
        e.preventDefault()
        const form = this.el.closest('form')
        if (form) {
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
        }
      }
    })

    // Focus input when panel expands
    const panel = document.getElementById('global-chat-panel')
    if (panel && panel.dataset.collapsed === 'false') {
      this.el.focus()
    }
  }
}
