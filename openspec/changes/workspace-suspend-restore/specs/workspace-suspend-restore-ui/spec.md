## ADDED Requirements

### Requirement: Suspended workspaces section in sidebar
The system SHALL display a "Suspended" section below the active workspace list in the sidebar when there are one or more suspended workspaces. The section SHALL include a header with the label "Suspended" and a count badge showing the number of suspended workspaces.

#### Scenario: Section visible when suspended workspaces exist
- **WHEN** the SuspendedWorkspaceStore contains one or more entries
- **THEN** a "Suspended" section appears below the active workspace list in the sidebar

#### Scenario: Section hidden when no suspended workspaces
- **WHEN** the SuspendedWorkspaceStore is empty
- **THEN** no "Suspended" section appears in the sidebar

### Requirement: Suspended workspace row displays metadata
Each suspended workspace row in the sidebar SHALL display: the workspace display name (title or directory basename), the git branch (if available), and a relative time label showing how long ago it was suspended (e.g., "2m ago", "1h ago", "3d ago").

#### Scenario: Row shows name and branch
- **WHEN** a suspended workspace has display name "my-project" and branch "main"
- **THEN** the row shows "my-project" as primary text and "main" as secondary text

#### Scenario: Row shows relative time
- **WHEN** a workspace was suspended 45 minutes ago
- **THEN** the row shows "45m ago" as a time label

### Requirement: Click to restore suspended workspace
The system SHALL restore a suspended workspace when the user clicks on its row in the Suspended section. The restored workspace SHALL appear in the active workspace list and become the selected workspace.

#### Scenario: Single click restores
- **WHEN** the user clicks a suspended workspace row labeled "my-project"
- **THEN** a new workspace is created from the snapshot, added to the active tabs, selected, and the suspended entry is removed from the store

### Requirement: Permanent delete from suspended list
The system SHALL provide a way to permanently delete a suspended workspace — either via a trailing close button (×) on the row, or via a context menu item "Delete Permanently". Permanent delete SHALL remove the entry from the SuspendedWorkspaceStore without restoring it.

#### Scenario: Close button permanently deletes
- **WHEN** the user clicks the × button on a suspended workspace row
- **THEN** the entry is permanently removed from the store and no workspace is created

#### Scenario: Context menu permanent delete
- **WHEN** the user right-clicks a suspended workspace row and selects "Delete Permanently"
- **THEN** the entry is permanently removed from the store

### Requirement: Collapsible suspended section
The suspended workspaces section in the sidebar SHALL be collapsible. The collapse state SHALL persist across app restarts via UserDefaults.

#### Scenario: Toggle collapse
- **WHEN** the user clicks the "Suspended" section header
- **THEN** the section toggles between collapsed and expanded states

#### Scenario: Collapse state persists
- **WHEN** the user collapses the section, quits the app, and relaunches
- **THEN** the section remains collapsed

### Requirement: Command palette restore integration
The command palette SHALL include a "Restore Workspace" command when suspended workspaces exist. Activating it SHALL enter a workspace-switcher-like mode showing suspended workspaces as searchable results. Selecting a result SHALL restore that workspace.

#### Scenario: Restore command appears in palette
- **WHEN** the user opens the command palette and there are suspended workspaces
- **THEN** a "Restore Suspended Workspace" command appears in the command list

#### Scenario: Fuzzy search over suspended workspaces
- **WHEN** the user activates "Restore Suspended Workspace" and types "auth"
- **THEN** suspended workspaces whose name, branch, or directory contain "auth" appear as results

### Requirement: Context menu on active workspace includes Suspend
The existing right-click context menu on active workspace rows in the sidebar SHALL include a "Suspend Workspace" option that suspends the workspace (snapshot + soft close).

#### Scenario: Context menu suspend
- **WHEN** the user right-clicks an active workspace and selects "Suspend Workspace"
- **THEN** the workspace is suspended: snapshot taken, added to SuspendedWorkspaceStore, workspace removed from active list
