## Why

cmux workspaces are ephemeral — when you close one, its entire state (terminal scrollback, splits, browser panels, git context) is permanently destroyed. Users who run many parallel coding agent sessions need to context-switch frequently but can't preserve inactive workspaces without keeping them all open and consuming resources. Zellij solves this with persistent sessions you can detach from and reattach to. cmux needs the same capability: "soft close" a workspace to free its resources while preserving its state for later restoration.

## What Changes

- **Workspace suspend**: Closing a workspace now defaults to "suspending" it — capturing a full snapshot before teardown. The workspace disappears from the active tab list but its state is preserved on disk.
- **Workspace restore**: A new UI in the sidebar shows suspended workspaces. Users can click to restore any suspended workspace, recreating its terminals, splits, scrollback, and browser panels.
- **Permanent close**: Users can permanently delete a suspended workspace from the restore UI, or force-close (bypass suspend) when closing an active workspace.
- **Persistence across app restarts**: Suspended workspace snapshots persist to disk and survive app quit/relaunch.
- **Command palette integration**: "Restore Workspace" appears in the command palette with fuzzy search over suspended workspace names/branches.
- **Keyboard shortcut**: Dedicated shortcut for suspend (default: Cmd+Shift+W) distinct from close.

## Capabilities

### New Capabilities
- `suspended-workspace-store`: Data model and persistence for suspended workspace snapshots, including save/load/delete operations and metadata (name, branch, directory, suspend timestamp)
- `workspace-suspend-restore-ui`: Sidebar UI section showing suspended workspaces with restore and permanent-delete actions, plus command palette integration
- `workspace-suspend-lifecycle`: TabManager integration for suspend (snapshot + teardown) and restore (create + replay snapshot) lifecycle, including keyboard shortcuts

### Modified Capabilities
<!-- No existing openspec capabilities are being modified -->

## Impact

- **Sources/TabManager.swift**: New `suspendWorkspace()` and `restoreWorkspace()` methods; modified close flow
- **Sources/ContentView.swift**: New sidebar section for suspended workspaces; command palette commands
- **Sources/SessionPersistence.swift**: New `SuspendedWorkspaceSnapshot` model extending existing snapshot infrastructure
- **Sources/AppDelegate.swift**: Wire up suspended workspace store, persist on quit, load on launch
- **Sources/Workspace.swift**: Minor — ensure `sessionSnapshot()` captures all needed state before teardown
- **Sources/KeyboardShortcutSettings.swift**: New shortcut binding for workspace suspend
- **Disk**: New file at `Application Support/cmux/suspended-workspaces.json`
- **No breaking changes**: Existing close behavior is preserved as "permanent close" option
