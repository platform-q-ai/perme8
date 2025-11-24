/**
 * InitializeCollaborativeEditor - Application Layer Use Case
 *
 * Orchestrates the initialization of a collaborative Milkdown editor with Yjs synchronization.
 * This use case coordinates between infrastructure adapters to set up the complete
 * collaborative editing environment.
 *
 * Responsibilities:
 * - Create and configure Yjs document with initial state
 * - Create and configure Yjs awareness for user tracking
 * - Initialize Milkdown editor with plugins
 * - Configure ProseMirror collaboration plugins
 * - Set up document and awareness synchronization
 *
 * Application Layer Characteristics:
 * - Orchestrates multiple infrastructure adapters
 * - Contains workflow logic (order of operations)
 * - Depends only on interfaces (dependency inversion)
 * - Framework-agnostic business logic
 *
 * @module application/use-cases
 */

import { commonmark } from '@milkdown/preset-commonmark'
import { gfm } from '@milkdown/preset-gfm'
import { nord } from '@milkdown/theme-nord'
import { clipboard } from '@milkdown/plugin-clipboard'
import { Awareness } from 'y-protocols/awareness'
import { YjsDocumentAdapter } from '../../infrastructure/yjs/yjs-document-adapter'
import { YjsAwarenessAdapter } from '../../infrastructure/yjs/yjs-awareness-adapter'
import { MilkdownEditorAdapter } from '../../infrastructure/milkdown/milkdown-editor-adapter'
import { ProseMirrorCollaborationAdapter } from '../../infrastructure/prosemirror/prosemirror-collaboration-adapter'
import { UserId } from '../../domain/value-objects/user-id'
import { UserColorAssignment } from '../../domain/policies/user-color-assignment'
// Import agent response node for AI agent integration
import { agentResponseNode } from '../../infrastructure/milkdown/agent-response-node-schema'
// Import task list click plugin for GFM checkbox toggling
import { taskListClickPlugin } from '../../infrastructure/milkdown/task-list-click-plugin'
// Import markdown input rules for auto-converting [text](url) and ![alt](url)
import { markdownInputRulesPlugin } from '../../infrastructure/milkdown/markdown-input-rules-plugin'
// Import link click plugin for Cmd/Ctrl+Click to open links
import { linkClickPlugin } from '../../infrastructure/milkdown/link-click-plugin'

/**
 * Configuration for initializing collaborative editor
 */
export interface InitializeEditorConfig {
  element: HTMLElement
  initialYjsState?: string
  userId: string
  userName: string
  onAgentQuery?: (data: { question: string; nodeId: string; agentName?: string }) => void
}

/**
 * Result of editor initialization
 */
export interface InitializedEditor {
  milkdownAdapter: MilkdownEditorAdapter
  yjsDocumentAdapter: YjsDocumentAdapter
  yjsAwarenessAdapter: YjsAwarenessAdapter
  collaborationAdapter: ProseMirrorCollaborationAdapter
}

/**
 * Use case for initializing a collaborative editor
 *
 * This use case encapsulates the complex workflow of setting up a collaborative
 * Milkdown editor with Yjs synchronization. It ensures proper initialization order
 * and wires up all necessary adapters.
 *
 * Usage:
 * ```typescript
 * const useCase = new InitializeCollaborativeEditor()
 * const result = await useCase.execute({
 *   element: document.getElementById('editor'),
 *   initialYjsState: 'base64string',
 *   userId: 'user-123',
 *   userName: 'John Doe'
 * })
 * ```
 */
export class InitializeCollaborativeEditor {
  /**
   * Execute the use case
   *
   * Workflow:
   * 1. Create Yjs document adapter with initial state
   * 2. Create Yjs awareness adapter
   * 3. Set initial awareness state (user info)
   * 4. Create Milkdown editor adapter
   * 5. Initialize Milkdown with plugins
   * 6. Create collaboration adapter
   * 7. Configure ProseMirror with collaboration plugins
   *
   * @param config - Configuration for editor initialization
   * @returns Initialized editor and adapters
   */
  async execute(config: InitializeEditorConfig): Promise<InitializedEditor> {
    // Step 1: Create Yjs document adapter with initial state
    const yjsDocumentAdapter = new YjsDocumentAdapter(config.initialYjsState)

    // Step 2: Create awareness instance from Yjs document
    const awareness = new Awareness(yjsDocumentAdapter.getYDoc())
    const yjsAwarenessAdapter = new YjsAwarenessAdapter(awareness)

    // Step 3: Set initial awareness state (user identification)
    const userId = new UserId(config.userId)
    const userColor = UserColorAssignment.assignColor(userId)

    yjsAwarenessAdapter.setLocalState({
      userId: config.userId,
      userName: config.userName,
      userColor: userColor.hex,
      selection: null
    })

    // Step 4: Create Milkdown editor adapter
    const milkdownAdapter = new MilkdownEditorAdapter(config.element)

    // Step 5: Initialize Milkdown editor with standard plugins
    await milkdownAdapter.create([
      nord,                      // Theme
      commonmark,                // CommonMark spec
      gfm,                       // GitHub Flavored Markdown  
      clipboard,                 // Clipboard support
      agentResponseNode,         // Custom node for AI agent responses
      markdownInputRulesPlugin,  // Auto-convert [text](url) as you type
      linkClickPlugin,           // Cmd/Ctrl+Click to open links in new tab
      taskListClickPlugin        // GFM task list checkbox toggling - Last so it runs first
    ])

    // Step 6: Create collaboration adapter
    // Pass onAgentQuery so it can add the plugin BEFORE existing plugins
    const collaborationAdapter = new ProseMirrorCollaborationAdapter({
      documentAdapter: yjsDocumentAdapter,
      awarenessAdapter: yjsAwarenessAdapter,
      userId: config.userId,
      onAgentQuery: config.onAgentQuery
    })

    // Step 7: Get editor view and configure collaboration plugins
    const view = milkdownAdapter.getEditorView()

    if (!view) {
      throw new Error('Failed to get editor view after initialization')
    }

    const state = view.state
    const newState = collaborationAdapter.configureProseMirrorPlugins(view, state)
    view.updateState(newState)

    // Return all adapters for lifecycle management
    return {
      milkdownAdapter,
      yjsDocumentAdapter,
      yjsAwarenessAdapter,
      collaborationAdapter
    }
  }
}
