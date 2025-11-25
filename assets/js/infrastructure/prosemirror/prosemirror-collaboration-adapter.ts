/**
 * ProseMirrorCollaborationAdapter - Infrastructure Layer
 *
 * Handles configuration of ProseMirror plugins for Y

js collaboration.
 * This includes setting up y-prosemirror plugins, undo/redo, awareness, and keymaps.
 *
 * Infrastructure Layer Characteristics:
 * - Wraps ProseMirror and y-prosemirror plugin configuration
 * - Manages plugin lifecycle and state
 * - Provides clean interface for collaboration setup
 *
 * @module infrastructure/prosemirror
 */

import * as Y from "yjs";
import {
  ySyncPlugin,
  yUndoPlugin,
  ySyncPluginKey,
  undo,
  redo,
} from "y-prosemirror";
import { keymap } from "prosemirror-keymap";
import { Plugin } from "@milkdown/prose/state";
import { Awareness } from "y-protocols/awareness";
import { createAwarenessPlugin } from "./awareness-plugin-factory";
import { createAgentMentionPlugin } from "./agent-mention-plugin-factory";
import type { YjsDocumentAdapter } from "../yjs/yjs-document-adapter";
import type { YjsAwarenessAdapter } from "../yjs/yjs-awareness-adapter";

/**
 * Configuration for ProseMirror collaboration plugins
 */
export interface CollaborationConfig {
  documentAdapter: YjsDocumentAdapter;
  awarenessAdapter: YjsAwarenessAdapter;
  userId: string;
  onAgentQuery?: (data: { command: string; nodeId: string }) => void;
}

/**
 * Result of configuring ProseMirror with collaboration plugins
 */
export interface CollaborationPlugins {
  ySyncPlugin: Plugin;
  yUndoPlugin: Plugin;
  undoRedoKeymap: Plugin;
  awarenessPlugin: Plugin;
  selectionPlugin: Plugin;
  agentMentionPlugin?: Plugin;
  undoManager: Y.UndoManager;
}

/**
 * ProseMirror collaboration adapter
 *
 * Configures ProseMirror editor view with Yjs collaboration plugins.
 * Handles setup of ySyncPlugin, yUndoPlugin, awareness, and selection tracking.
 */
export class ProseMirrorCollaborationAdapter {
  private config: CollaborationConfig;
  private undoManager?: Y.UndoManager;

  constructor(config: CollaborationConfig) {
    this.config = config;
  }

  /**
   * Configure ProseMirror editor with collaboration plugins
   *
   * Strategy:
   * 1. Apply ySyncPlugin for Yjs collaboration
   * 2. Create UndoManager that tracks only local changes
   * 3. Apply yUndoPlugin for undo/redo state management
   * 4. Add keyboard shortcuts for undo/redo
   * 5. Add awareness plugin for cursor/selection tracking
   * 6. Add selection tracking plugin
   *
   * @param view - ProseMirror editor view
   * @param state - ProseMirror editor state
   * @returns New editor state with collaboration plugins
   */
  configureProseMirrorPlugins(view: any, state: any): any {
    const yXmlFragment = this.config.documentAdapter.getYXmlFragment();
    const awareness = this.config.awarenessAdapter.getAwareness();

    // Step 1: Apply ySyncPlugin for collaboration
    const ySync = ySyncPlugin(yXmlFragment);
    let newState = state.reconfigure({
      plugins: [...state.plugins, ySync],
    });
    view.updateState(newState);

    // Step 2: Get the binding from ySyncPlugin
    const ySyncState = ySyncPluginKey.getState(view.state);
    const binding = ySyncState?.binding;

    if (!binding) {
      throw new Error("No binding found after adding ySyncPlugin");
    }

    // Step 3: Create UndoManager that tracks only this binding's changes
    const undoManager = new Y.UndoManager(yXmlFragment, {
      trackedOrigins: new Set([binding]),
    });

    // Step 4: Attach UndoManager to binding so yUndoPlugin can use it
    binding.undoManager = undoManager;
    this.undoManager = undoManager;

    // Step 5: Add yUndoPlugin for undo/redo state management
    const yUndo = yUndoPlugin();

    // Step 6: Add keyboard shortcuts for undo/redo
    const undoRedoKeymap = keymap({
      "Mod-z": undo,
      "Mod-y": redo,
      "Mod-Shift-z": redo,
    });

    // Step 7: Add awareness plugin for cursor/selection tracking
    const awarenessPlugin = createAwarenessPlugin(
      awareness,
      this.config.userId,
    );

    // Step 8: Add selection tracking plugin
    const selectionPlugin = this.createSelectionPlugin(awareness);

    // Step 9: Build plugin list - agent mention MUST be last (processed first)
    const newPlugins = [
      yUndo,
      undoRedoKeymap,
      awarenessPlugin,
      selectionPlugin,
    ];

    // Add agent mention plugin if callback provided
    // MUST be added last so it processes handleDOMEvents first
    if (this.config.onAgentQuery) {
      const agentMentionPlugin = createAgentMentionPlugin(
        view.state.schema,
        this.config.onAgentQuery
      );
      newPlugins.push(agentMentionPlugin);
    }

    // Step 10: Apply all plugins - APPEND new plugins to existing
    // IMPORTANT: ProseMirror processes handleKeyDown in REVERSE order!
    // Later plugins (higher index) get first chance at handling keys
    // So we APPEND to be last (processed first)
    newState = view.state.reconfigure({
      plugins: [...view.state.plugins, ...newPlugins],
    });

    return newState;
  }

  /**
   * Create a selection tracking plugin
   *
   * Tracks user's selection and updates awareness state.
   *
   * @param awareness - Yjs Awareness instance
   * @returns ProseMirror plugin
   */
  private createSelectionPlugin(awareness: Awareness): Plugin {
    return new Plugin({
      view: () => ({
        update: (view, prevState) => {
          const state = view.state;
          const selection = state.selection;

          // Only update if selection actually changed
          if (!prevState || !prevState.selection.eq(selection)) {
            const localState = awareness.getLocalState();
            awareness.setLocalState({
              ...localState,
              selection: {
                from: selection.from,
                to: selection.to,
                anchor: selection.anchor,
                head: selection.head,
              },
            });
          }
        },
      }),
    });
  }

  /**
   * Get the UndoManager instance
   */
  getUndoManager(): Y.UndoManager | undefined {
    return this.undoManager;
  }

  /**
   * Clean up resources
   */
  destroy(): void {
    if (this.undoManager) {
      this.undoManager.destroy();
      this.undoManager = undefined;
    }
  }
}
