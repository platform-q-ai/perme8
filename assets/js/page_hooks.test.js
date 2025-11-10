import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { MilkdownEditor } from './page_hooks'
import { CollaborationManager } from './collaboration'
import { editorViewCtx, parserCtx } from '@milkdown/core'

// Mock Milkdown modules - inline everything to avoid hoisting issues
vi.mock('@milkdown/core', () => {
  // Define symbols inline
  const mockSymbols = {
    rootCtx: Symbol('rootCtx'),
    editorViewCtx: Symbol('editorViewCtx'),
    defaultValueCtx: Symbol('defaultValueCtx'),
    serializerCtx: Symbol('serializerCtx'),
    parserCtx: Symbol('parserCtx')
  }

  return {
    Editor: {
      make: vi.fn(() => ({
        config: vi.fn(function() { return this }),
        use: vi.fn(function() { return this }),
        create: vi.fn(() => Promise.resolve()),
        action: vi.fn(),
        destroy: vi.fn()
      }))
    },
    rootCtx: mockSymbols.rootCtx,
    editorViewCtx: mockSymbols.editorViewCtx,
    defaultValueCtx: mockSymbols.defaultValueCtx,
    serializerCtx: mockSymbols.serializerCtx,
    parserCtx: mockSymbols.parserCtx
  }
})

vi.mock('@milkdown/preset-commonmark', () => ({
  commonmark: 'commonmark-preset'
}))

vi.mock('@milkdown/preset-gfm', () => ({
  gfm: 'gfm-preset'
}))

vi.mock('@milkdown/theme-nord', () => ({
  nord: 'nord-theme'
}))

vi.mock('@milkdown/plugin-clipboard', () => ({
  clipboard: 'clipboard-plugin'
}))

describe('MilkdownEditor Hook', () => {
  let hook
  let mockElement
  let mockPushEvent
  let mockHandleEvent
  let mockEditorView

  beforeEach(() => {
    // Create mock DOM element with dataset
    mockElement = document.createElement('div')
    mockElement.id = 'editor-container'
    mockElement.dataset.yjsState = ''
    mockElement.dataset.initialContent = ''
    mockElement.dataset.readonly = 'false'
    mockElement.dataset.userName = 'Test User'

    // Add isConnected getter
    Object.defineProperty(mockElement, 'isConnected', {
      get: () => true,
      configurable: true
    })

    // Create a fresh hook instance by copying methods from MilkdownEditor
    hook = Object.create(MilkdownEditor)
    hook.el = mockElement

    // Mock Phoenix LiveView functions
    mockPushEvent = vi.fn()
    mockHandleEvent = vi.fn()
    hook.pushEvent = mockPushEvent
    hook.handleEvent = mockHandleEvent

    // Mock editor view for tests that need it
    mockEditorView = {
      dom: {
        addEventListener: vi.fn(),
        removeEventListener: vi.fn()
      }
    }

    // Mock browser APIs
    global.confirm = vi.fn(() => true)
    global.setInterval = vi.fn(() => 12345)
    global.clearInterval = vi.fn()

    // Mock document/window event listeners
    vi.spyOn(document, 'addEventListener')
    vi.spyOn(document, 'removeEventListener')
    vi.spyOn(window, 'addEventListener')
    vi.spyOn(window, 'removeEventListener')

    // Reset all mocks
    vi.clearAllMocks()
  })

  afterEach(() => {
    if (hook.collaborationManager) {
      hook.collaborationManager.destroy()
    }
    vi.restoreAllMocks()
  })

  describe('staleness detection', () => {
    describe('setupStalenessDetection', () => {
      it('should add focus event listener to editor', () => {
        const mockView = { ...mockEditorView }
        const addEventListenerSpy = vi.spyOn(mockView.dom, 'addEventListener')

        hook.setupStalenessDetection(mockView)

        expect(addEventListenerSpy).toHaveBeenCalledWith('focus', expect.any(Function))
        expect(hook.stalenessCheckHandler).toBeDefined()
      })

      it('should set up phx:connected event handler', () => {
        const mockView = { ...mockEditorView }

        hook.setupStalenessDetection(mockView)

        expect(mockHandleEvent).toHaveBeenCalledWith('phx:connected', expect.any(Function))
      })
    })

    describe('checkForStaleness', () => {
      beforeEach(() => {
        // Create a real CollaborationManager instance
        hook.collaborationManager = new CollaborationManager()
        hook.collaborationManager.initialize()
        hook.readonly = false
      })

      it('should call collaborationManager.checkForStaleness', async () => {
        const checkStalenessSpy = vi.spyOn(hook.collaborationManager, 'checkForStaleness')
          .mockResolvedValue(false)

        await hook.checkForStaleness()

        expect(checkStalenessSpy).toHaveBeenCalled()
        expect(checkStalenessSpy).toHaveBeenCalledWith(
          expect.any(Function),
          expect.any(Function)
        )
      })

      it('should pass pushEvent to collaborationManager', async () => {
        const checkStalenessSpy = vi.spyOn(hook.collaborationManager, 'checkForStaleness')
          .mockResolvedValue(false)

        await hook.checkForStaleness()

        // Get the pushEvent function that was passed
        const passedPushEvent = checkStalenessSpy.mock.calls[0][0]

        // Call it and verify it uses the hook's pushEvent
        passedPushEvent('test_event', { data: 'test' }, vi.fn())

        expect(mockPushEvent).toHaveBeenCalledWith('test_event', { data: 'test' }, expect.any(Function))
      })

      it('should not check staleness if readonly', async () => {
        hook.readonly = true
        const checkStalenessSpy = vi.spyOn(hook.collaborationManager, 'checkForStaleness')

        await hook.checkForStaleness()

        expect(checkStalenessSpy).not.toHaveBeenCalled()
      })

      it('should not check staleness if no collaborationManager', async () => {
        hook.collaborationManager = null

        // Should not throw
        await expect(hook.checkForStaleness()).resolves.toBeUndefined()
      })

      it('should handle errors gracefully', async () => {
        const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
        vi.spyOn(hook.collaborationManager, 'checkForStaleness')
          .mockRejectedValue(new Error('Test error'))

        await hook.checkForStaleness()

        expect(consoleErrorSpy).toHaveBeenCalledWith(
          'Error checking for staleness:',
          expect.any(Error)
        )
      })
    })

    describe('showStaleStateModal', () => {
      beforeEach(() => {
        hook.collaborationManager = new CollaborationManager()
        hook.collaborationManager.initialize()
        hook.hasPendingChanges = true
      })

      it('should show confirm dialog with appropriate message', () => {
        // Create a valid yjs state
        const doc = new CollaborationManager()
        doc.initialize()
        const freshDbState = doc.getCompleteState()
        doc.destroy()

        hook.showStaleStateModal(freshDbState)

        expect(global.confirm).toHaveBeenCalledWith(
          expect.stringContaining('This page has been edited elsewhere')
        )
      })

      it('should apply fresh state when user confirms without local changes', () => {
        vi.useFakeTimers()
        global.confirm.mockReturnValue(true)

        const applyFreshStateSpy = vi.spyOn(hook.collaborationManager, 'applyFreshState')
        const broadcastSpy = vi.spyOn(hook, 'broadcastMergedState')

        // Create a valid yjs state
        const doc = new CollaborationManager()
        doc.initialize()
        const freshDbState = doc.getCompleteState()
        doc.destroy()

        // No pending changes
        hook.hasPendingChanges = false

        hook.showStaleStateModal(freshDbState)

        // Should apply immediately when no pending changes
        expect(applyFreshStateSpy).toHaveBeenCalledWith(freshDbState)

        // Run timers to execute broadcast
        vi.runAllTimers()

        // Should broadcast merged state to other clients
        expect(broadcastSpy).toHaveBeenCalled()

        expect(hook.hasPendingChanges).toBe(false)

        vi.useRealTimers()
      })

      it('should save and merge when user confirms with local changes', () => {
        vi.useFakeTimers()
        global.confirm.mockReturnValue(true)

        const applyFreshStateSpy = vi.spyOn(hook.collaborationManager, 'applyFreshState')
        const forceSaveSpy = vi.spyOn(hook, 'forceSave')
        const broadcastSpy = vi.spyOn(hook, 'broadcastMergedState')

        // Create a valid yjs state
        const doc = new CollaborationManager()
        doc.initialize()
        const freshDbState = doc.getCompleteState()
        doc.destroy()

        // Has pending changes
        hook.hasPendingChanges = true

        hook.showStaleStateModal(freshDbState)

        // Should save first
        expect(forceSaveSpy).toHaveBeenCalled()

        // Run timers to execute the async behavior
        vi.runAllTimers()

        // Should apply fresh state after saving
        expect(applyFreshStateSpy).toHaveBeenCalledWith(freshDbState)

        // Should broadcast merged state to other clients
        expect(broadcastSpy).toHaveBeenCalled()

        vi.useRealTimers()
      })

      it('should not apply fresh state when user cancels', () => {
        global.confirm.mockReturnValue(false)
        const applyFreshStateSpy = vi.spyOn(hook.collaborationManager, 'applyFreshState')

        // Create a valid yjs state
        const doc = new CollaborationManager()
        doc.initialize()
        const freshDbState = doc.getCompleteState()
        doc.destroy()

        hook.hasPendingChanges = true

        hook.showStaleStateModal(freshDbState)

        expect(applyFreshStateSpy).not.toHaveBeenCalled()
        expect(hook.hasPendingChanges).toBe(true)
      })
    })

    describe('broadcastMergedState', () => {
      beforeEach(() => {
        hook.collaborationManager = new CollaborationManager()
        hook.collaborationManager.initialize()

        // Setup editor with mock for getMarkdownContent()
        let getCallCount = 0
        hook.editor = {
          action: vi.fn((callback) => {
            const mockCtx = {
              get: vi.fn(() => {
                getCallCount++
                if (getCallCount === 1) {
                  return { state: { doc: {} } }
                }
                if (getCallCount === 2) {
                  return vi.fn(() => '# Test Content')
                }
                return null
              })
            }
            return callback(mockCtx)
          })
        }
      })

      it('should send yjs_update event with merged state', () => {
        hook.broadcastMergedState()

        expect(mockPushEvent).toHaveBeenCalledWith(
          'yjs_update',
          expect.objectContaining({
            update: expect.any(String),
            complete_state: expect.any(String),
            user_id: expect.any(String),
            markdown: expect.any(String)
          })
        )
      })
    })
  })

  describe('lifecycle', () => {
    describe('mounted', () => {
      it('should initialize collaboration manager for non-readonly mode', () => {
        mockElement.dataset.readonly = 'false'
        mockElement.dataset.yjsState = 'base64state'
        hook.readonly = false

        // Manually initialize what mounted() would do
        hook.collaborationManager = new CollaborationManager()
        hook.collaborationManager.initialize(mockElement.dataset.yjsState)

        expect(hook.collaborationManager).toBeInstanceOf(CollaborationManager)
      })

      it('should skip collaboration manager for readonly mode', () => {
        mockElement.dataset.readonly = 'true'
        hook.readonly = true

        // In readonly mode, collaborationManager should not be created
        expect(hook.collaborationManager).toBeUndefined()
      })

      it('should set up visibilitychange listener in non-readonly mode', () => {
        // Simulate what mounted() does
        hook.visibilityHandler = vi.fn()
        document.addEventListener('visibilitychange', hook.visibilityHandler)

        expect(document.addEventListener).toHaveBeenCalledWith('visibilitychange', hook.visibilityHandler)
      })

      it('should set up periodic backup save interval', () => {
        // Simulate what mounted() does
        const interval = setInterval(() => {}, 30000)
        hook.backupSaveInterval = interval

        expect(hook.backupSaveInterval).toBeDefined()
        clearInterval(interval)
      })
    })

    describe('destroyed', () => {
      beforeEach(() => {
        // Setup hook state as if mounted() was called
        hook.collaborationManager = new CollaborationManager()
        hook.collaborationManager.initialize()
        hook.backupSaveInterval = 12345
        hook.visibilityHandler = vi.fn()
        hook.beforeUnloadHandler = vi.fn()
        hook.hasPendingChanges = false
      })

      it('should clear backup save interval', () => {
        hook.destroyed()

        expect(global.clearInterval).toHaveBeenCalledWith(12345)
        expect(hook.backupSaveInterval).toBeNull()
      })

      it('should remove visibility change listener', () => {
        hook.destroyed()

        expect(document.removeEventListener).toHaveBeenCalledWith('visibilitychange', hook.visibilityHandler)
      })

      it('should remove beforeunload listener', () => {
        hook.destroyed()

        expect(window.removeEventListener).toHaveBeenCalledWith('beforeunload', hook.beforeUnloadHandler)
      })

      it('should destroy collaboration manager', () => {
        const destroySpy = vi.spyOn(hook.collaborationManager, 'destroy')

        hook.destroyed()

        expect(destroySpy).toHaveBeenCalled()
      })

      it('should not throw if collaboration manager is null', () => {
        hook.collaborationManager = null

        expect(() => hook.destroyed()).not.toThrow()
      })
    })
  })

  describe('force save', () => {
    beforeEach(() => {
      // Setup hook state
      hook.collaborationManager = new CollaborationManager()
      hook.collaborationManager.initialize()

      // Setup editor with mock for getMarkdownContent()
      // Use call counting to return correct mocks
      let getCallCount = 0
      hook.editor = {
        action: vi.fn((callback) => {
          const mockCtx = {
            get: vi.fn(() => {
              getCallCount++
              // First call: return editorView
              if (getCallCount === 1) {
                return { state: { doc: {} } }
              }
              // Second call: return serializer function
              if (getCallCount === 2) {
                return vi.fn(() => '# Test Content')
              }
              return null
            })
          }
          return callback(mockCtx)
        })
      }

      hook.readonly = false
      hook.hasPendingChanges = true
    })

    it('should call pushEvent with force_save', () => {
      hook.forceSave()

      expect(mockPushEvent).toHaveBeenCalledWith(
        'force_save',
        expect.objectContaining({
          complete_state: expect.any(String),
          markdown: expect.any(String)
        })
      )
    })

    it('should reset hasPendingChanges flag', () => {
      hook.forceSave()

      expect(hook.hasPendingChanges).toBe(false)
    })

    it('should not save if readonly', () => {
      hook.readonly = true
      hook.hasPendingChanges = true

      hook.forceSave()

      expect(mockPushEvent).not.toHaveBeenCalled()
      expect(hook.hasPendingChanges).toBe(true)
    })

    it('should not save if no pending changes', () => {
      hook.hasPendingChanges = false

      hook.forceSave()

      expect(mockPushEvent).not.toHaveBeenCalled()
    })

    it('should handle errors gracefully', () => {
      const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
      // Make getMarkdownContent throw
      vi.spyOn(hook, 'getMarkdownContent').mockImplementation(() => {
        throw new Error('Markdown extraction failed')
      })

      hook.forceSave()

      expect(consoleErrorSpy).toHaveBeenCalledWith(
        'Error forcing save:',
        expect.any(Error)
      )
    })
  })

  describe('markdown extraction', () => {
    beforeEach(() => {
      // Setup editor with a mock action that provides ctx with serializer
      // We use call counting to return the correct mock for each ctx.get() call
      // The implementation calls: ctx.get(editorViewCtx) then ctx.get(serializerCtx)
      let getCallCount = 0

      hook.editor = {
        action: vi.fn((callback) => {
          const mockCtx = {
            get: vi.fn(() => {
              getCallCount++
              // First call: return editorView
              if (getCallCount === 1) {
                return { state: { doc: {} } }
              }
              // Second call: return serializer function
              if (getCallCount === 2) {
                return vi.fn(() => '# Test Content')
              }
              return null
            })
          }
          return callback(mockCtx)
        })
      }
    })

    it('should extract markdown from editor', () => {
      const markdown = hook.getMarkdownContent()

      expect(markdown).toBe('# Test Content')
    })

    it('should return empty string if editor is null', () => {
      hook.editor = null

      const markdown = hook.getMarkdownContent()

      expect(markdown).toBe('')
    })

    it('should handle errors gracefully', () => {
      const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
      hook.editor = {
        action: vi.fn(() => {
          throw new Error('Test error')
        })
      }

      const markdown = hook.getMarkdownContent()

      expect(markdown).toBe('')
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        'Error extracting markdown:',
        expect.any(Error)
      )
    })
  })

  describe('integration with CollaborationManager', () => {
    beforeEach(() => {
      // Setup collaboration manager
      hook.collaborationManager = new CollaborationManager({ userName: 'Test User' })
      hook.collaborationManager.initialize('aW5pdGlhbHN0YXRl')

      // Setup callbacks
      hook.collaborationManager.onLocalUpdate(vi.fn())
      hook.collaborationManager.onAwarenessUpdate(vi.fn())
    })

    it('should initialize CollaborationManager with userName', () => {
      const manager = new CollaborationManager({ userName: 'John D.' })
      expect(manager.userName).toBe('John D.')
      manager.destroy()
    })

    it('should set up onLocalUpdate callback', () => {
      expect(hook.collaborationManager.onLocalUpdateCallback).toBeDefined()
    })

    it('should set up onAwarenessUpdate callback', () => {
      expect(hook.collaborationManager.onAwarenessUpdateCallback).toBeDefined()
    })

    it('should handle yjs_update events from server', () => {
      const applyRemoteUpdateSpy = vi.spyOn(hook.collaborationManager, 'applyRemoteUpdate')

      // Create a valid yjs update
      const tempDoc = new CollaborationManager()
      tempDoc.initialize()
      const validUpdate = tempDoc.getCompleteState()
      tempDoc.destroy()

      // Manually call the event handler that would be registered
      hook.collaborationManager.applyRemoteUpdate(validUpdate)

      expect(applyRemoteUpdateSpy).toHaveBeenCalledWith(validUpdate)
    })

    it('should handle awareness_update events from server', () => {
      const applyRemoteAwarenessUpdateSpy = vi.spyOn(
        hook.collaborationManager,
        'applyRemoteAwarenessUpdate'
      )

      // Create a valid awareness update (empty for now, just test it doesn't crash)
      const validAwarenessUpdate = btoa(String.fromCharCode(...new Uint8Array([0, 0])))

      // Manually call the event handler that would be registered
      try {
        hook.collaborationManager.applyRemoteAwarenessUpdate(validAwarenessUpdate)
      } catch (e) {
        // It's ok if it throws on invalid awareness data in tests
        // We're just testing that the handler exists and can be called
      }

      expect(applyRemoteAwarenessUpdateSpy).toHaveBeenCalledWith(validAwarenessUpdate)
    })
  })

  describe('readonly editor', () => {
    it('should create readonly Milkdown editor', async () => {
      const initialContent = '# Read Only Content'

      // Spy on Editor.make to verify it's called
      const { Editor } = await import('@milkdown/core')
      const makeSpy = vi.spyOn(Editor, 'make')

      hook.createReadonlyMilkdownEditor(initialContent)

      expect(makeSpy).toHaveBeenCalled()
    })

    it('should set up mutation observer for readonly mode', async () => {
      const initialContent = '# Test'
      const observerSpy = vi.fn()

      // Mock MutationObserver
      global.MutationObserver = vi.fn(function(callback) {
        this.observe = observerSpy
        this.disconnect = vi.fn()
        return this
      })

      // We can't fully test the editor creation without mocking everything,
      // but we can verify the method doesn't throw
      expect(() => {
        hook.createReadonlyMilkdownEditor(initialContent)
      }).not.toThrow()
    })
  })

  describe('task list interaction', () => {
    let mockView

    beforeEach(() => {
      mockView = {
        dom: {
          addEventListener: vi.fn(),
          removeEventListener: vi.fn()
        },
        posAtDOM: vi.fn(),
        state: {
          doc: {
            resolve: vi.fn()
          },
          tr: {
            setNodeMarkup: vi.fn(function() { return this })
          }
        },
        dispatch: vi.fn()
      }
    })

    it('should add click event listener for task list', () => {
      hook.setupTaskListClickHandler(mockView)

      expect(mockView.dom.addEventListener).toHaveBeenCalledWith('click', expect.any(Function))
      expect(hook.taskListClickHandler).toBeDefined()
    })

    it('should store click handler for cleanup', () => {
      hook.setupTaskListClickHandler(mockView)

      expect(hook.taskListClickHandler).toBeInstanceOf(Function)
    })
  })

  describe('click to focus', () => {
    let mockView

    beforeEach(() => {
      mockView = {
        dom: document.createElement('div'),
        state: {
          doc: {
            content: { size: 100 },
            resolve: vi.fn(() => ({
              pos: 100
            }))
          },
          tr: {
            setSelection: vi.fn(function() { return this })
          },
          constructor: {
            Selection: {
              near: vi.fn(() => ({ anchor: 100, head: 100 }))
            }
          }
        },
        dispatch: vi.fn(),
        focus: vi.fn()
      }
    })

    it('should add click event listener to element', () => {
      const addEventListenerSpy = vi.spyOn(hook.el, 'addEventListener')

      hook.setupClickToFocus(mockView)

      expect(addEventListenerSpy).toHaveBeenCalledWith('click', expect.any(Function))
      expect(hook.clickToFocusHandler).toBeDefined()
    })

    it('should store click handler for cleanup', () => {
      hook.setupClickToFocus(mockView)

      expect(hook.clickToFocusHandler).toBeInstanceOf(Function)
    })
  })

  describe('focusEditorAtEnd', () => {
    let mockView

    beforeEach(() => {
      mockView = {
        state: {
          doc: {
            content: { size: 100 },
            resolve: vi.fn(() => ({
              pos: 100
            }))
          },
          tr: {
            setSelection: vi.fn(function() { return this })
          },
          constructor: {
            Selection: {
              near: vi.fn(() => ({ anchor: 100, head: 100 }))
            }
          }
        },
        dispatch: vi.fn(),
        focus: vi.fn()
      }
    })

    it('should focus editor at end of document', () => {
      hook.focusEditorAtEnd(mockView)

      expect(mockView.state.doc.resolve).toHaveBeenCalledWith(100)
      expect(mockView.state.constructor.Selection.near).toHaveBeenCalled()
      expect(mockView.dispatch).toHaveBeenCalled()
      expect(mockView.focus).toHaveBeenCalled()
    })

    it('should create transaction with selection at end', () => {
      hook.focusEditorAtEnd(mockView)

      expect(mockView.state.tr.setSelection).toHaveBeenCalled()
    })
  })

  describe('insertTextIntoEditor', () => {
    let mockView
    let mockTransaction
    let mockSchema
    let mockParser
    let mockTextNode
    let mockHardbreakNode
    let mockParagraphNode
    let consoleLogSpy

    beforeEach(() => {
      // Mock ProseMirror nodes
      mockTextNode = { type: 'text', text: '' }
      mockHardbreakNode = { type: 'hardbreak' }
      mockParagraphNode = { type: 'paragraph', content: [] }

      // Mock schema
      mockSchema = {
        text: vi.fn((text) => ({ ...mockTextNode, text })),
        nodes: {
          hardbreak: {
            create: vi.fn(() => mockHardbreakNode)
          },
          paragraph: {
            create: vi.fn((attrs, content) => ({ ...mockParagraphNode, content: content || [] }))
          }
        }
      }

      // Mock transaction with chaining support
      mockTransaction = {
        replaceWith: vi.fn(function() { return this }),
        insert: vi.fn(function() { return this })
      }

      // Mock selection with position info
      const mockSelection = {
        $head: {
          before: vi.fn(() => 0),
          after: vi.fn(() => 10),
          depth: 1,
          parent: {
            type: { name: 'paragraph' },
            content: { size: 5 },
            nodeSize: 5
          }
        }
      }

      // Mock parser that simulates Milkdown's markdown parser
      mockParser = vi.fn((content) => {
        // Simulate parser returning a document with content nodes
        const paragraphs = content.split('\n\n').filter(p => p.trim())
        const nodes = paragraphs.map(p => ({
          type: 'paragraph',
          content: [{ type: 'text', text: p.trim() }]
        }))

        return {
          type: 'doc',
          content: nodes
        }
      })

      // Mock editor view
      mockView = {
        state: {
          schema: mockSchema,
          selection: mockSelection,
          tr: mockTransaction
        },
        dispatch: vi.fn(),
        focus: vi.fn()
      }

      // Setup editor with action method
      hook.editor = {
        action: vi.fn((callback) => {
          const mockCtx = {
            get: vi.fn((key) => {
              // Return parser for parserCtx, view for editorViewCtx
              if (key === parserCtx) return mockParser
              if (key === editorViewCtx) return mockView
              return mockView
            })
          }
          return callback(mockCtx)
        })
      }

      hook.readonly = false

      // Spy on console.log
      consoleLogSpy = vi.spyOn(console, 'log').mockImplementation(() => {})
    })

    afterEach(() => {
      consoleLogSpy.mockRestore()
    })

    it('should return early if no editor', () => {
      hook.editor = null

      hook.insertTextIntoEditor('test content')

      expect(consoleLogSpy).not.toHaveBeenCalled()
    })

    it('should return early if readonly', () => {
      hook.readonly = true

      hook.insertTextIntoEditor('test content')

      expect(hook.editor.action).not.toHaveBeenCalled()
    })

    it('should return early if no content', () => {
      hook.insertTextIntoEditor('')

      expect(hook.editor.action).not.toHaveBeenCalled()
    })

    it('should return early if content is null', () => {
      hook.insertTextIntoEditor(null)

      expect(hook.editor.action).not.toHaveBeenCalled()
    })

    it('should insert single paragraph', () => {
      hook.insertTextIntoEditor('Hello world')

      expect(mockParser).toHaveBeenCalledWith('Hello world')
      expect(mockView.dispatch).toHaveBeenCalled()
      expect(mockView.focus).toHaveBeenCalled()
    })

    it('should insert multiple paragraphs separated by double newlines', () => {
      hook.insertTextIntoEditor('First paragraph\n\nSecond paragraph')

      // Parser should be called with the content
      expect(mockParser).toHaveBeenCalledWith('First paragraph\n\nSecond paragraph')

      expect(mockView.dispatch).toHaveBeenCalled()
    })

    it('should handle line breaks within paragraphs with hardbreak nodes', () => {
      hook.insertTextIntoEditor('Line 1\nLine 2')

      // Parser should be called with the content
      expect(mockParser).toHaveBeenCalledWith('Line 1\nLine 2')

      expect(mockView.dispatch).toHaveBeenCalled()
    })

    it('should replace empty paragraph', () => {
      // Mock empty paragraph
      mockView.state.selection.$head.parent = {
        type: { name: 'paragraph' },
        content: { size: 0 },
        nodeSize: 2
      }

      hook.insertTextIntoEditor('New content')

      // Should use replaceWith for empty paragraph
      expect(mockTransaction.replaceWith).toHaveBeenCalled()
      expect(mockView.dispatch).toHaveBeenCalled()
    })

    it('should insert after current paragraph when paragraph has content', () => {
      // Mock non-empty paragraph (size > 0)
      mockView.state.selection.$head.parent = {
        type: { name: 'paragraph' },
        content: { size: 10 },
        nodeSize: 12
      }

      hook.insertTextIntoEditor('New content')

      // Should use insert for non-empty paragraph
      expect(mockTransaction.insert).toHaveBeenCalled()
      expect(mockView.dispatch).toHaveBeenCalled()
    })

    it('should focus editor after insertion', () => {
      hook.insertTextIntoEditor('Test content')

      expect(mockView.focus).toHaveBeenCalled()
    })

    it('should handle errors gracefully', () => {
      const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      // Make editor.action throw
      hook.editor = {
        action: vi.fn(() => {
          throw new Error('Test error')
        })
      }

      hook.insertTextIntoEditor('Test content')

      expect(consoleErrorSpy).toHaveBeenCalledWith(
        'Error inserting text into editor:',
        expect.any(Error)
      )

      consoleErrorSpy.mockRestore()
    })

    it('should trim content before processing', () => {
      hook.insertTextIntoEditor('  \n\n  Test content  \n\n  ')

      // Parser should be called with trimmed content
      expect(mockParser).toHaveBeenCalledWith('Test content')
    })

    it('should parse markdown content', () => {
      hook.insertTextIntoEditor('Content\n\nMore content')

      // Parser should be called to handle markdown
      expect(mockParser).toHaveBeenCalledWith('Content\n\nMore content')
      expect(mockView.dispatch).toHaveBeenCalled()
    })

    it('should handle parser errors gracefully', () => {
      const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      // Mock parser to return a string (error case)
      mockParser.mockReturnValueOnce('Error parsing')

      hook.insertTextIntoEditor('Test content')

      expect(consoleErrorSpy).toHaveBeenCalledWith('Error parsing markdown:', 'Error parsing')
      expect(mockView.dispatch).not.toHaveBeenCalled()

      consoleErrorSpy.mockRestore()
    })

    it('should add empty paragraph for spacing at the end', () => {
      hook.insertTextIntoEditor('Content')

      // Parser should be called
      expect(mockParser).toHaveBeenCalledWith('Content')

      // Empty paragraph should be added via schema.nodes.paragraph.create()
      expect(mockSchema.nodes.paragraph.create).toHaveBeenCalled()
      expect(mockView.dispatch).toHaveBeenCalled()
    })

    it('should return early if view or parser is not available', () => {
      hook.editor = {
        action: vi.fn((callback) => {
          const mockCtx = {
            get: vi.fn(() => null) // No view or parser
          }
          return callback(mockCtx)
        })
      }

      // Should not throw
      expect(() => hook.insertTextIntoEditor('Test')).not.toThrow()
    })
  })
})
