/**
 * JavaScript hooks for the chat panel component
 * Handles responsive panel state, keyboard shortcuts, and auto-scroll
 */

export const ChatPanel = {
  mounted() {
    this.toggleBtn = document.getElementById('chat-toggle-btn')
    this.userInteracted = false // Track if user has manually toggled

    // Desktop breakpoint (lg in Tailwind)
    this.DESKTOP_BREAKPOINT = 1024

    // Check if screen is desktop size
    this.isDesktop = () => {
      return window.innerWidth >= this.DESKTOP_BREAKPOINT
    }

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
    })

    // Set initial state based on screen size (responsive defaults)
    // Desktop: open by default, Mobile/tablet: closed by default
    if (this.isDesktop()) {
      this.el.checked = true
    } else {
      this.el.checked = false
    }

    // Initial button visibility
    this.updateButtonVisibility()

    // Handle window resize - update panel state if crossing breakpoint
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

    // Mark as user interaction on click
    this.el.addEventListener('click', () => {
      this.userInteracted = true
    })

    // Keyboard shortcut: Cmd/Ctrl + K to toggle
    this.handleKeyboard = (e) => {
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
    if (this.handleResize) {
      window.removeEventListener('resize', this.handleResize)
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
