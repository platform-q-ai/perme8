/**
 * Hooks Entry Point
 *
 * This file serves as the main entry point for all Phoenix LiveView hooks.
 * Hooks are organized following Clean Architecture principles.
 *
 * Architecture:
 * - presentation/hooks/ - Thin Phoenix hooks (this layer)
 * - application/use-cases/ - Business workflows
 * - infrastructure/ - External integrations (Yjs, ProseMirror, Milkdown, LiveView)
 * - domain/ - Pure business logic
 *
 * IMPORTANT: Phoenix LiveView expects hooks to be plain objects or constructors,
 * not class instances. We export the class constructors directly so Phoenix can
 * instantiate them.
 */

// Import hook classes from Clean Architecture presentation layer
import { MilkdownEditorHook } from './presentation/hooks/milkdown-editor-hook'
import { DocumentTitleHook } from './presentation/hooks/document-title-hook'
import { ChatPanelHook } from './presentation/hooks/chat-panel-hook'
import { ChatMessagesHook } from './presentation/hooks/chat-messages-hook'
import { ChatInputHook } from './presentation/hooks/chat-input-hook'
import { FlashHook } from './presentation/hooks/flash-hook'

// Export individual hooks for selective import
export {
  MilkdownEditorHook as MilkdownEditor,
  DocumentTitleHook as DocumentTitleInput,
  ChatPanelHook as ChatPanel,
  ChatMessagesHook as ChatMessages,
  ChatInputHook as ChatInput,
  FlashHook as AutoHideFlash
}

// Default export for Phoenix LiveView
// Phoenix will call `new HookClass()` for each hook, so we export the constructors
export default {
  MilkdownEditor: MilkdownEditorHook,
  ChatPanel: ChatPanelHook,
  ChatMessages: ChatMessagesHook,
  ChatInput: ChatInputHook,
  AutoHideFlash: FlashHook,
  DocumentTitleInput: DocumentTitleHook
}
