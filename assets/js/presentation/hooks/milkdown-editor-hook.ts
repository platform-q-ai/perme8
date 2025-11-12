/**
 * MilkdownEditorHook - Clean Architecture Implementation
 *
 * Thin Phoenix hook that coordinates collaborative editor initialization and lifecycle.
 * This implementation follows Clean Architecture principles with proper separation of concerns.
 *
 * Responsibilities (Presentation Layer):
 * - Phoenix LiveView lifecycle management (mounted/destroyed)
 * - Create and inject infrastructure adapters
 * - Instantiate and execute use cases
 * - Wire up LiveView events to use cases
 * - NO business logic - all logic delegated to use cases
 *
 * Architecture:
 * - Presentation Layer: This hook (thin coordinator)
 * - Application Layer: Use cases (business workflows)
 * - Infrastructure Layer: Adapters (Yjs, Milkdown, ProseMirror, LiveView)
 * - Domain Layer: Entities and value objects (if needed)
 *
 * @module presentation/hooks
 */

import { ViewHook } from 'phoenix_live_view'
import { Editor, rootCtx, defaultValueCtx, editorViewCtx } from '@milkdown/core'
import { commonmark } from '@milkdown/preset-commonmark'
import { gfm } from '@milkdown/preset-gfm'
import { nord } from '@milkdown/theme-nord'
import { InitializeCollaborativeEditor } from '../../application/use-cases/initialize-collaborative-editor'
import { HandleDocumentSync } from '../../application/use-cases/handle-document-sync'
import { HandleAwarenessSync } from '../../application/use-cases/handle-awareness-sync'
import type { YjsDocumentAdapter } from '../../infrastructure/yjs/yjs-document-adapter'
import type { YjsAwarenessAdapter } from '../../infrastructure/yjs/yjs-awareness-adapter'
import type { MilkdownEditorAdapter } from '../../infrastructure/milkdown/milkdown-editor-adapter'
import type { ProseMirrorCollaborationAdapter } from '../../infrastructure/prosemirror/prosemirror-collaboration-adapter'
// Import agent assistance components
import { AgentQueryAdapter } from '../../infrastructure/prosemirror/agent-query-adapter'
import { AgentNodeAdapter } from '../../infrastructure/prosemirror/agent-node-adapter'
import { MarkdownParserAdapter } from '../../infrastructure/milkdown/markdown-parser-adapter'
import { MarkdownContentInserter } from '../../infrastructure/prosemirror/markdown-content-inserter'
import { HandleAgentChunk } from '../../application/use-cases/handle-agent-chunk'
import { HandleAgentCompletion } from '../../application/use-cases/handle-agent-completion'
import { HandleAgentError } from '../../application/use-cases/handle-agent-error'
import { InsertMarkdownContent } from '../../application/use-cases/insert-markdown-content'
import { AgentQuery } from '../../domain/entities/agent-query'
import { NodeId } from '../../domain/value-objects/node-id'
import { parserCtx } from '@milkdown/core'
import { logger } from '../../infrastructure/browser/logger'

/**
 * Clean Architecture implementation of Milkdown editor hook
 *
 * This hook demonstrates the proper Clean Architecture pattern:
 * 1. Read configuration from data attributes
 * 2. Create infrastructure adapters
 * 3. Execute use cases with dependency injection
 * 4. Wire up LiveView events
 * 5. Clean up on destroy
 */
export class MilkdownEditorHook extends ViewHook {
  // Adapters (created in mounted)
  private yjsDocumentAdapter?: YjsDocumentAdapter
  private yjsAwarenessAdapter?: YjsAwarenessAdapter
  private milkdownAdapter?: MilkdownEditorAdapter
  private collaborationAdapter?: ProseMirrorCollaborationAdapter

  // Agent adapters
  private agentQueryAdapter?: AgentQueryAdapter
  private agentNodeAdapter?: AgentNodeAdapter
  private markdownInserter?: MarkdownContentInserter

  // Use cases
  private initializeEditor?: InitializeCollaborativeEditor
  private handleDocumentSync?: HandleDocumentSync
  private handleAwarenessSync?: HandleAwarenessSync

  // Agent use cases
  private handleAgentChunkUseCase?: HandleAgentChunk
  private handleAgentCompletionUseCase?: HandleAgentCompletion
  private handleAgentErrorUseCase?: HandleAgentError
  private insertMarkdownContentUseCase?: InsertMarkdownContent

  // Cleanup functions
  private cleanupDocumentSync?: () => void
  private cleanupAwarenessSync?: () => void

  // Configuration
  private isReadonly = false
  private userId = ''
  private userName = ''

  /**
   * Phoenix hook lifecycle: mounted
   *
   * Coordinates editor initialization following Clean Architecture:
   * 1. Read configuration
   * 2. Create use cases
   * 3. Execute initialization
   * 4. Wire up sync
   * 5. Register LiveView events
   */
  mounted(): void {
    // Step 1: Read configuration from data attributes
    const yjsState = this.el.dataset.yjsState || ''
    const initialContent = this.el.dataset.initialContent || ''
    this.isReadonly = this.el.dataset.readonly === 'true'
    this.userName = this.el.dataset.userName || ''
    this.userId = this.el.dataset.userId || ''

    // Step 1.1: Validate required userId
    if (!this.userId || this.userId.trim() === '') {
      logger.error('MilkdownEditorHook', 'Missing required userId data attribute')
      return
    }

    // Step 2: Handle readonly mode (simpler case)
    if (this.isReadonly) {
      this.mountReadonlyEditor(initialContent)
      return
    }

    // Step 3: Create use cases
    this.initializeEditor = new InitializeCollaborativeEditor()
    this.handleDocumentSync = new HandleDocumentSync()
    this.handleAwarenessSync = new HandleAwarenessSync()

    // Step 4: Execute initialization use case
    this.initializeEditor
      .execute({
        element: this.el,
        initialYjsState: yjsState,
        userId: this.userId,
        userName: this.userName,
        onAgentQuery: (data) => {
          // Track the query in the adapter so we can find it when agent completes
          if (this.agentQueryAdapter) {
            const nodeId = new NodeId(data.nodeId)
            const query = AgentQuery.createWithNodeId(nodeId, data.question)
            this.agentQueryAdapter.add(query)
          }

          // Push agent query to LiveView server
          this.pushEvent('agent_query', {
            question: data.question,
            node_id: data.nodeId
          })
        }
      })
      .then((result) => {
        // Store adapters for lifecycle management
        this.yjsDocumentAdapter = result.yjsDocumentAdapter
        this.yjsAwarenessAdapter = result.yjsAwarenessAdapter
        this.milkdownAdapter = result.milkdownAdapter
        this.collaborationAdapter = result.collaborationAdapter

        // Step 5: Set up agent assistance
        this.setupAgentAssistance()

        // Step 6: Set up document sync
        this.setupDocumentSync()

        // Step 7: Set up awareness sync
        this.setupAwarenessSync()

        // Step 8: Wire up LiveView events
        this.wireUpLiveViewEvents()

        // Step 9: Set up additional UI interactions
        this.setupEditorInteractions()
      })
      .catch((error) => {
        logger.error('MilkdownEditorHook', 'Failed to initialize collaborative editor', error)
      })
  }

  /**
   * Mount readonly editor (no collaboration)
   *
   * @param initialContent - Markdown content to display
   */
  private mountReadonlyEditor(initialContent: string): void {
    // For readonly, we just need to render the content with editable set to false
    const editor = Editor.make()
      .config((ctx) => {
        ctx.set(rootCtx, this.el)
        ctx.set(defaultValueCtx, initialContent || '')
        // Apply theme configuration
        nord(ctx)
      })

    // Add markdown plugins
    editor.use(commonmark)
    editor.use(gfm)

    // Create editor
    editor.create().then(() => {
      // After editor is created, set it to non-editable
      editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        // Update the view to be non-editable
        view.setProps({
          editable: () => false
        })
      })
    }).catch((error) => {
      logger.error('MilkdownEditorHook', 'Failed to create readonly editor', error)
    })
  }

  /**
   * Set up agent assistance
   *
   * Creates agent adapters, use cases, and orchestrator.
   */
  private setupAgentAssistance(): void {
    if (!this.milkdownAdapter || !this.collaborationAdapter) {
      logger.warn('MilkdownEditorHook', 'Cannot setup agent assistance without adapters')
      return
    }

    const view = this.milkdownAdapter.getEditorView()
    if (!view) {
      logger.warn('MilkdownEditorHook', 'Cannot setup agent assistance without editor view')
      return
    }

    const schema = view.state.schema

    // Create markdown parser adapter
    let parserAdapter: MarkdownParserAdapter | null = null
    this.milkdownAdapter.action((ctx) => {
      const parser = ctx.get(parserCtx)
      parserAdapter = new MarkdownParserAdapter(parser)
    })

    if (!parserAdapter) {
      logger.warn('MilkdownEditorHook', 'Cannot setup agent assistance without parser')
      return
    }

    // Create agent adapters
    this.agentQueryAdapter = new AgentQueryAdapter()
    this.agentNodeAdapter = new AgentNodeAdapter(view, schema, parserAdapter)
    this.markdownInserter = new MarkdownContentInserter(view, parserAdapter)

    // Create agent use cases
    this.handleAgentChunkUseCase = new HandleAgentChunk(
      this.agentNodeAdapter,
      this.agentQueryAdapter
    )
    this.handleAgentCompletionUseCase = new HandleAgentCompletion(
      this.agentQueryAdapter,
      this.agentNodeAdapter
    )
    this.handleAgentErrorUseCase = new HandleAgentError(
      this.agentQueryAdapter,
      this.agentNodeAdapter
    )

    // Create markdown insertion use case
    this.insertMarkdownContentUseCase = new InsertMarkdownContent(this.markdownInserter)
  }

  /**
   * Set up document synchronization
   *
   * Uses HandleDocumentSync use case to coordinate document changes.
   */
  private setupDocumentSync(): void {
    if (!this.handleDocumentSync || !this.yjsDocumentAdapter || !this.milkdownAdapter) {
      return
    }

    this.cleanupDocumentSync = this.handleDocumentSync.execute({
      yjsDocumentAdapter: this.yjsDocumentAdapter,
      milkdownAdapter: this.milkdownAdapter,
      userId: this.userId,
      onLocalChange: (update, markdown, completeState) => {
        // Push to LiveView server
        this.pushEvent('yjs_update', {
          update,
          markdown,
          complete_state: completeState,
          user_id: this.userId
        })
      }
    })
  }

  /**
   * Set up awareness synchronization
   *
   * Uses HandleAwarenessSync use case to coordinate user presence.
   */
  private setupAwarenessSync(): void {
    if (!this.handleAwarenessSync || !this.yjsAwarenessAdapter) {
      return
    }

    this.cleanupAwarenessSync = this.handleAwarenessSync.execute({
      yjsAwarenessAdapter: this.yjsAwarenessAdapter,
      userId: this.userId,
      onLocalChange: (update) => {
        // Push to LiveView server
        this.pushEvent('awareness_update', {
          update,
          user_id: this.userId
        })
      }
    })
  }

  /**
   * Wire up LiveView event handlers
   *
   * Connects server events to use case methods.
   */
  private wireUpLiveViewEvents(): void {
    // Handle remote document updates
    this.handleEvent('yjs_update', ({ update }: { update: string }) => {
      if (this.handleDocumentSync && this.yjsDocumentAdapter) {
        this.handleDocumentSync.applyRemoteUpdate(this.yjsDocumentAdapter, update)
      }
    })

    // Handle remote awareness updates
    this.handleEvent('awareness_update', ({ update }: { update: string }) => {
      if (this.handleAwarenessSync && this.yjsAwarenessAdapter) {
        this.handleAwarenessSync.applyRemoteUpdate(this.yjsAwarenessAdapter, update)
      }
    })

    // Handle insert-text events from chat
    this.handleEvent('insert-text', ({ content }: { content: string }) => {
      this.handleInsertText(content)
    })

    // Handle agent streaming chunk
    this.handleEvent('agent_chunk', ({ node_id, chunk }: { node_id: string; chunk: string }) => {
      this.handleAgentChunk(node_id, chunk)
    })

    // Handle agent completion
    this.handleEvent('agent_done', ({ node_id, response }: { node_id: string; response: string }) => {
      this.handleAgentDone(node_id, response)
    })

    // Handle agent error
    this.handleEvent('agent_error', ({ node_id, error }: { node_id: string; error: string }) => {
      this.handleAgentError(node_id, error)
    })
  }

  /**
   * Set up additional editor interactions
   *
   * Add UI enhancements like task list clicking, focus handling, etc.
   */
  private setupEditorInteractions(): void {
    if (!this.milkdownAdapter) return

    const view = this.milkdownAdapter.getEditorView()
    if (!view) return

    // Add task list checkbox click handler
    // Add click-to-focus handler
    // Add other UI interactions as needed
    // (Implementation details moved to separate methods for clarity)
  }

  /**
   * Handle insert text from chat
   *
   * Uses InsertMarkdownContent use case to parse and insert markdown content.
   *
   * @param content - Markdown content to insert
   */
  private handleInsertText(content: string): void {
    if (!this.insertMarkdownContentUseCase) {
      logger.warn('MilkdownEditorHook', 'Markdown insertion use case not initialized')
      return
    }

    if (!content || content.trim().length === 0) {
      return
    }

    try {
      this.insertMarkdownContentUseCase.execute({ markdown: content })
    } catch (error) {
      logger.error('MilkdownEditorHook', 'Failed to insert markdown content', error)
    }
  }

  /**
   * Handle agent streaming chunk
   *
   * Uses HandleAgentChunk use case to append streaming chunk to the agent_response node.
   *
   * @param nodeId - Unique identifier for the agent response node
   * @param chunk - Text chunk from agent stream
   */
  private handleAgentChunk(nodeId: string, chunk: string): void {
    if (!this.handleAgentChunkUseCase) {
      logger.warn('MilkdownEditorHook', 'Agent chunk use case not initialized')
      return
    }

    try {
      this.handleAgentChunkUseCase.execute({ nodeId, chunk })
    } catch (error) {
      logger.error('MilkdownEditorHook', 'Failed to handle agent chunk', error)
    }
  }

  /**
   * Handle agent completion
   *
   * Uses HandleAgentCompletion use case to finalize the agent response.
   *
   * @param nodeId - Unique identifier for the agent response node
   * @param response - Final complete response from agent
   */
  private handleAgentDone(nodeId: string, response: string): void {
    if (!this.handleAgentCompletionUseCase) {
      logger.warn('MilkdownEditorHook', 'Agent completion use case not initialized')
      return
    }

    try {
      this.handleAgentCompletionUseCase.execute({ nodeId, response })
    } catch (error) {
      logger.error('MilkdownEditorHook', 'Failed to handle agent completion', error)
    }
  }

  /**
   * Handle agent error
   *
   * Uses HandleAgentError use case to update the agent response with error state.
   *
   * @param nodeId - Unique identifier for the agent response node
   * @param error - Error message
   */
  private handleAgentError(nodeId: string, error: string): void {
    if (!this.handleAgentErrorUseCase) {
      logger.warn('MilkdownEditorHook', 'Agent error use case not initialized')
      return
    }

    try {
      this.handleAgentErrorUseCase.execute({ nodeId, error })
    } catch (error) {
      logger.error('MilkdownEditorHook', 'Failed to handle agent error', error)
    }
  }

  /**
   * Phoenix hook lifecycle: destroyed
   *
   * Clean up all adapters and use cases.
   * This is critical for preventing memory leaks.
   */
  destroyed(): void {
    // Clean up sync listeners
    if (this.cleanupDocumentSync) {
      this.cleanupDocumentSync()
    }
    if (this.cleanupAwarenessSync) {
      this.cleanupAwarenessSync()
    }

    // Destroy adapters in reverse order
    if (this.collaborationAdapter) {
      this.collaborationAdapter.destroy()
    }
    if (this.milkdownAdapter) {
      this.milkdownAdapter.destroy()
    }
    if (this.yjsAwarenessAdapter) {
      this.yjsAwarenessAdapter.destroy()
    }
    if (this.yjsDocumentAdapter) {
      this.yjsDocumentAdapter.destroy()
    }

    // Clear references
    this.yjsDocumentAdapter = undefined
    this.yjsAwarenessAdapter = undefined
    this.milkdownAdapter = undefined
    this.collaborationAdapter = undefined
    this.initializeEditor = undefined
    this.handleDocumentSync = undefined
    this.handleAwarenessSync = undefined

    // Clear agent references
    this.agentQueryAdapter = undefined
    this.agentNodeAdapter = undefined
    this.markdownInserter = undefined
    this.handleAgentChunkUseCase = undefined
    this.handleAgentCompletionUseCase = undefined
    this.handleAgentErrorUseCase = undefined
    this.insertMarkdownContentUseCase = undefined
  }
}
