## ADDED Requirements

### Requirement: Suspend workspace captures snapshot before teardown
The system SHALL provide a `suspendWorkspace(_:)` method on TabManager that: (1) captures a `SessionWorkspaceSnapshot` with scrollback included, (2) creates a `SuspendedWorkspaceEntry` with metadata, (3) adds it to the `SuspendedWorkspaceStore`, (4) then performs the standard workspace close (teardown panels, remove from tabs).

#### Scenario: Suspend captures scrollback
- **WHEN** a workspace with 500 lines of terminal output is suspended
- **THEN** the `SessionWorkspaceSnapshot` stored in the `SuspendedWorkspaceEntry` includes the scrollback text

#### Scenario: Suspend removes from active tabs
- **WHEN** a workspace is suspended
- **THEN** it is removed from `TabManager.tabs` and the next workspace is selected (same behavior as close)

#### Scenario: Cannot suspend last workspace
- **WHEN** there is only one workspace in the window
- **THEN** `suspendWorkspace()` does nothing (guard, same as `closeWorkspace`)

### Requirement: Restore workspace from suspended entry
The system SHALL provide a `restoreWorkspace(entryId:)` method on TabManager that: (1) retrieves the snapshot from `SuspendedWorkspaceStore`, (2) creates a new `Workspace` with a fresh port ordinal, (3) calls `restoreSessionSnapshot()` on it, (4) attaches it to the tab list, (5) selects it, (6) removes the entry from the store.

#### Scenario: Restore creates working workspace
- **WHEN** a suspended workspace that had 2 terminal panels and 1 browser panel is restored
- **THEN** the new workspace has 2 terminal panels and 1 browser panel with their original layout

#### Scenario: Restore replays scrollback
- **WHEN** a suspended workspace with terminal scrollback is restored
- **THEN** the restored terminal panels show the preserved scrollback text via `SessionScrollbackReplayStore`

#### Scenario: Restored workspace is selected
- **WHEN** a workspace is restored
- **THEN** it becomes the active (selected) workspace in the sidebar

### Requirement: Default close action suspends instead of destroying
The system SHALL change the default workspace close behavior: when a workspace has at least one terminal panel with non-empty scrollback or a custom title, closing SHALL suspend rather than permanently destroy. Workspaces with no meaningful state (empty, freshly created) SHALL be permanently closed as before.

#### Scenario: Close with content suspends
- **WHEN** the user closes a workspace that has terminal output in at least one panel
- **THEN** the workspace is suspended (snapshot preserved) instead of permanently destroyed

#### Scenario: Close empty workspace permanently closes
- **WHEN** the user closes a workspace where all terminal panels have empty scrollback and no custom title
- **THEN** the workspace is permanently destroyed (no snapshot taken)

### Requirement: Force permanent close option
The system SHALL provide a way to permanently close a workspace without suspending, via a "Close Permanently" context menu option and by holding Option while clicking the close button.

#### Scenario: Option+click close button permanently closes
- **WHEN** the user holds Option and clicks the workspace close button
- **THEN** the workspace is permanently destroyed without creating a suspended entry

#### Scenario: Context menu close permanently
- **WHEN** the user right-clicks a workspace and selects "Close Permanently"
- **THEN** the workspace is permanently destroyed without creating a suspended entry

### Requirement: Keyboard shortcut for suspend
The system SHALL support a keyboard shortcut (default: Cmd+Shift+W) that suspends the current workspace. This SHALL be distinct from the existing close shortcut.

#### Scenario: Cmd+Shift+W suspends current workspace
- **WHEN** the user presses Cmd+Shift+W with a workspace that has content
- **THEN** the current workspace is suspended

#### Scenario: Shortcut blocked when only one workspace
- **WHEN** the user presses Cmd+Shift+W with only one workspace open
- **THEN** nothing happens

### Requirement: SuspendedWorkspaceStore wired in AppDelegate
The `SuspendedWorkspaceStore` SHALL be created during app initialization in `AppDelegate`, loaded from disk, and injected as an environment object to all windows. It SHALL be accessible from TabManager for suspend/restore operations.

#### Scenario: Store available at window creation
- **WHEN** a new window is created
- **THEN** the `SuspendedWorkspaceStore` is available as an environment object

#### Scenario: Store loads persisted data on launch
- **WHEN** the app launches with a suspended workspaces file on disk
- **THEN** the store is populated with the persisted entries before any window is shown
