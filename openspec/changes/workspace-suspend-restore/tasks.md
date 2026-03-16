## 1. Data Model & Store

- [x] 1.1 Create `SuspendedWorkspaceEntry` struct in a new `Sources/SuspendedWorkspaceStore.swift` file — UUID id, originalWorkspaceId, displayName, directory, gitBranch, suspendedAt timestamp, and `SessionWorkspaceSnapshot` payload
- [x] 1.2 Create `SuspendedWorkspaceStore` ObservableObject class with `@Published var entries: [SuspendedWorkspaceEntry]`, add/remove/restore methods, and 50-entry FIFO cap
- [x] 1.3 Implement JSON persistence — `save()` and `load()` methods writing to `Application Support/cmux/suspended-workspaces-<bundleId>.json`, auto-save after every mutation
- [x] 1.4 Wire `SuspendedWorkspaceStore` in `AppDelegate` — create instance, load from disk on launch, inject as environment object to all windows

## 2. Suspend Lifecycle (TabManager)

- [x] 2.1 Add `suspendedWorkspaceStore` property to `TabManager` (set by AppDelegate, like `window`)
- [x] 2.2 Implement `suspendWorkspace(_:)` on TabManager — capture snapshot with scrollback, build `SuspendedWorkspaceEntry`, add to store, then call existing `closeWorkspace()`
- [x] 2.3 Implement `restoreWorkspace(entryId:)` on TabManager — retrieve snapshot from store, create new Workspace, call `restoreSessionSnapshot()`, attach to tabs, select it, remove from store
- [x] 2.4 Add `hasMeaningfulState` helper on Workspace — returns true if any terminal panel has non-empty scrollback or workspace has a custom title
- [x] 2.5 Modify close flow: `closeWorkspaceIfRunningProcess` and `closeWorkspaceWithConfirmation` to suspend (if meaningful state) instead of permanently close by default
- [x] 2.6 Add `permanentlyCloseWorkspace(_:)` method that bypasses suspend and calls original `closeWorkspace()` directly

## 3. Sidebar UI — Suspended Section

- [x] 3.1 Create `SuspendedWorkspaceSidebarSection` SwiftUI view — collapsible section with "Suspended" header, count badge, and list of suspended workspace rows
- [x] 3.2 Create `SuspendedWorkspaceRow` SwiftUI view — shows display name, git branch, relative time ("2m ago"), trailing × delete button
- [x] 3.3 Add the `SuspendedWorkspaceSidebarSection` to `VerticalTabsSidebar` body, below the active workspace list and above the footer
- [x] 3.4 Implement click-to-restore — tapping a suspended row calls `tabManager.restoreWorkspace(entryId:)`
- [x] 3.5 Implement permanent delete — × button and context menu "Delete Permanently" removes from store
- [x] 3.6 Persist collapse state via `@AppStorage("suspendedSectionCollapsed")`
- [x] 3.7 Localize all new UI strings with `String(localized:defaultValue:)`

## 4. Context Menu & Keyboard Shortcuts

- [x] 4.1 Add "Suspend Workspace" to the existing right-click context menu on active workspace sidebar rows
- [x] 4.2 Add "Close Permanently" to the existing right-click context menu on active workspace sidebar rows
- [x] 4.3 Add keyboard shortcut Cmd+Shift+W for suspending current workspace — add to `KeyboardShortcutSettings` and wire in `AppDelegate` or `ContentView` key handler
- [ ] 4.4 Support Option+click on workspace close button to force permanent close (detect modifier in close button action)

## 5. Command Palette Integration

- [x] 5.1 Add "Restore Suspended Workspace" command to the command palette command list (in `ContentView` command palette setup)
- [x] 5.2 When activated, show suspended workspaces as searchable results with name/branch/directory as search text
- [x] 5.3 Selecting a result calls `tabManager.restoreWorkspace(entryId:)` and dismisses the palette

## 6. Polish & Edge Cases

- [ ] 6.1 Handle edge case: restoring when at max workspace limit (`maxWorkspacesPerWindow = 128`) — show alert or silently fail
- [x] 6.2 Ensure suspended workspace store cleanup on `applicationWillTerminate` — final save to disk
- [x] 6.3 Update discovery log with implementation notes and any architectural decisions made during coding
