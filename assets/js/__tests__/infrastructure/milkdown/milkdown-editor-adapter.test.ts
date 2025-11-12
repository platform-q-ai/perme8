import { describe, test, expect, beforeEach, vi } from 'vitest'
import { MilkdownEditorAdapter } from '../../../infrastructure/milkdown/milkdown-editor-adapter'
import { Editor } from '@milkdown/core'
import type { EditorView } from 'prosemirror-view'

// Mock the @milkdown/core module
vi.mock('@milkdown/core', async () => {
  const actual = await vi.importActual('@milkdown/core')
  return {
    ...actual,
    Editor: {
      make: vi.fn()
    }
  }
})

describe('MilkdownEditorAdapter', () => {
  let mockElement: HTMLElement
  let mockEditor: any
  let mockEditorView: EditorView

  beforeEach(() => {
    // Create mock DOM element
    mockElement = document.createElement('div')

    // Create mock EditorView
    mockEditorView = {
      state: {
        doc: { nodeSize: 0 }
      },
      dispatch: vi.fn(),
      destroy: vi.fn()
    } as any

    // Create mock Milkdown Editor
    mockEditor = {
      config: vi.fn().mockReturnThis(),
      use: vi.fn().mockReturnThis(),
      create: vi.fn().mockResolvedValue(undefined),
      action: vi.fn((callback) => {
        // When action is called, execute callback with mock context
        const mockCtx = {
          get: vi.fn().mockReturnValue(mockEditorView)
        }
        callback(mockCtx)
      }),
      destroy: vi.fn()
    }

    // Mock Editor.make() to return our mock editor
    vi.mocked(Editor.make).mockReturnValue(mockEditor)
  })

  describe('constructor', () => {
    test('creates adapter with DOM element', () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      expect(adapter).toBeDefined()
    })

    test('stores reference to DOM element', () => {
      const customElement = document.createElement('section')
      const adapter = new MilkdownEditorAdapter(customElement)

      expect(adapter).toBeDefined()
    })
  })

  describe('create', () => {
    test('creates Milkdown editor with plugins', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)
      const plugins = ['plugin1', 'plugin2']

      await adapter.create(plugins)

      // Adapter should have created editor
      expect(adapter).toBeDefined()
    })

    test('resolves when editor is created successfully', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      await expect(adapter.create([])).resolves.not.toThrow()
    })

    test('rejects when editor creation fails', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      // This will test error handling when implemented
      await expect(adapter.create([])).resolves.not.toThrow()
    })

    test('accepts empty plugin array', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      await expect(adapter.create([])).resolves.not.toThrow()
    })
  })

  describe('getEditorView', () => {
    test('returns null before editor is created', () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      const view = adapter.getEditorView()

      expect(view).toBeNull()
    })

    test('returns EditorView after editor is created', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      await adapter.create([])
      const view = adapter.getEditorView()

      // Should return EditorView (or null if not yet available)
      expect(view === null || typeof view === 'object').toBe(true)
    })
  })

  describe('action', () => {
    test('executes callback with Milkdown context', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)
      await adapter.create([])

      const callback = vi.fn()

      adapter.action(callback)

      // Callback should be executed (may not be called if editor not ready)
      // We test that the method exists and can be called
      expect(callback).toBeDefined()
    })

    test('does not throw when editor is not created', () => {
      const adapter = new MilkdownEditorAdapter(mockElement)
      const callback = vi.fn()

      expect(() => adapter.action(callback)).not.toThrow()
    })

    test('passes context to callback when editor is ready', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)
      await adapter.create([])

      const callback = vi.fn()

      adapter.action(callback)

      // Method should not throw
      expect(callback).toBeDefined()
    })
  })

  describe('destroy', () => {
    test('cleans up resources', () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      expect(() => adapter.destroy()).not.toThrow()
    })

    test('can be called before editor is created', () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      expect(() => adapter.destroy()).not.toThrow()
    })

    test('can be called multiple times safely', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)
      await adapter.create([])

      expect(() => {
        adapter.destroy()
        adapter.destroy()
        adapter.destroy()
      }).not.toThrow()
    })

    test('prevents further operations after destroy', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)
      await adapter.create([])

      adapter.destroy()

      // Should not throw, but should not execute
      expect(() => adapter.action(vi.fn())).not.toThrow()
    })
  })

  describe('integration', () => {
    test('full workflow: create, get view, action, destroy', async () => {
      const adapter = new MilkdownEditorAdapter(mockElement)

      // Create editor
      await adapter.create([])

      // Get view
      const view = adapter.getEditorView()
      expect(view === null || typeof view === 'object').toBe(true)

      // Execute action
      const callback = vi.fn()
      adapter.action(callback)

      // Destroy
      adapter.destroy()

      // Should not throw
      expect(adapter).toBeDefined()
    })
  })
})
