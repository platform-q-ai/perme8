/**
 * JavaScript hooks for the chat panel component
 * Handles localStorage persistence, keyboard shortcuts, and auto-scroll
 */

export const ChatPanel = {
  mounted() {
    this.toggleBtn = document.getElementById('chat-toggle-btn')

    // Store reference to update function
    this.updateButtonVisibility = () => {
      if (!this.toggleBtn) {
        this.toggleBtn = document.getElementById('chat-toggle-btn')
      }

      if (this.toggleBtn) {
        if (this.el.checked) {
          this.toggleBtn.classList.add('hidden')
        } else {
          this.toggleBtn.classList.remove('hidden')
        }
      }
    }

    // Watch for checkbox changes
    this.el.addEventListener('change', () => {
      this.updateButtonVisibility()

      if (this.el.checked) {
        // Drawer is opening - focus the input after animation
        setTimeout(() => {
          const input = document.getElementById('chat-input')
          if (input) {
            input.focus()
          }
        }, 150)
      }

      // Save state to localStorage
      localStorage.setItem('chat_collapsed', !this.el.checked)
    })

    // Load collapsed state from localStorage
    const collapsed = localStorage.getItem('chat_collapsed')
    if (collapsed !== null) {
      this.el.checked = collapsed === 'false'
    }

    // Initial button visibility
    this.updateButtonVisibility()

    // Listen for server events to manage localStorage
    this.handleEvent('save_session', ({ session_id }) => {
      localStorage.setItem('current_chat_session_id', session_id)
    })

    this.handleEvent('clear_session', () => {
      localStorage.removeItem('current_chat_session_id')
    })

    // Restore session from localStorage on mount (after a short delay to ensure LiveView is ready)
    setTimeout(() => {
      const sessionId = localStorage.getItem('current_chat_session_id')
      if (sessionId) {
        // Get the component target from phx-target attribute
        const target = this.el.getAttribute('phx-target')
        if (target) {
          this.pushEventTo(target, 'restore_session', { session_id: sessionId })
        } else {
          this.pushEvent('restore_session', { session_id: sessionId })
        }
      }
    }, 100)

    // Keyboard shortcut: Cmd/Ctrl + K to toggle
    this.handleKeyboard = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        this.el.click()
      }

      // Escape to close
      if (e.key === 'Escape' && this.el.checked) {
        this.el.click()
      }
    }

    document.addEventListener('keydown', this.handleKeyboard)
  },

  updated() {
    // Ensure button visibility is correct after LiveView updates
    if (this.updateButtonVisibility) {
      this.updateButtonVisibility()
    }
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
    // Submit on Enter (without Shift), Shift+Enter for new line
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        const form = this.el.closest('form')
        if (form && this.el.value.trim() !== '') {
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
        }
      }
      // Shift+Enter will create a new line (default textarea behavior)
    })
  },

  updated() {
    // Keep focus on input after form submission and LiveView updates
    // Only refocus if drawer is still open
    const drawer = document.getElementById(this.el.closest('.drawer').querySelector('input[type="checkbox"]').id)
    if (drawer && drawer.checked && document.activeElement !== this.el) {
      this.el.focus()
    }
  }
}
