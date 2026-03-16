## ADDED Requirements

### Requirement: SuspendedWorkspaceEntry data model
The system SHALL define a `SuspendedWorkspaceEntry` struct that wraps a `SessionWorkspaceSnapshot` with metadata: a unique ID (UUID), display name (derived from workspace title/directory/branch), the original workspace ID, suspended timestamp, original working directory, and original git branch name.

#### Scenario: Entry captures workspace metadata at suspend time
- **WHEN** a workspace with title "my-project", directory "/Users/dev/my-project", and git branch "feature/auth" is suspended
- **THEN** a `SuspendedWorkspaceEntry` is created with those values as display metadata, a new UUID, the current timestamp, and the full `SessionWorkspaceSnapshot`

#### Scenario: Entry preserves original workspace ID
- **WHEN** a workspace with ID `abc-123` is suspended
- **THEN** the `SuspendedWorkspaceEntry.originalWorkspaceId` equals `abc-123`

### Requirement: SuspendedWorkspaceStore manages entries
The system SHALL provide a `SuspendedWorkspaceStore` class conforming to `ObservableObject` that maintains a `@Published` array of `SuspendedWorkspaceEntry` items, ordered by suspended timestamp (most recent first).

#### Scenario: Store starts empty
- **WHEN** the store is initialized without loading from disk
- **THEN** the entries array is empty

#### Scenario: Adding an entry publishes the change
- **WHEN** a new `SuspendedWorkspaceEntry` is added to the store
- **THEN** the `@Published` entries array updates and SwiftUI observers are notified

### Requirement: Maximum 50 suspended workspaces with FIFO eviction
The system SHALL enforce a maximum of 50 suspended workspaces. When adding a new entry would exceed this limit, the oldest entry (by suspended timestamp) SHALL be permanently removed before adding the new one.

#### Scenario: Adding when at capacity evicts oldest
- **WHEN** the store has 50 entries and a new workspace is suspended
- **THEN** the entry with the oldest `suspendedAt` timestamp is removed and the new entry is added

#### Scenario: Adding when under capacity does not evict
- **WHEN** the store has 30 entries and a new workspace is suspended
- **THEN** all 30 existing entries are preserved and the new entry is added (total: 31)

### Requirement: Persist to disk as JSON
The system SHALL persist suspended workspaces to `Application Support/cmux/suspended-workspaces-<bundleId>.json` using JSON encoding. The store SHALL load from this file on initialization and save after every mutation (add, remove, restore).

#### Scenario: Persists after suspend
- **WHEN** a workspace is suspended and added to the store
- **THEN** the JSON file on disk contains the new entry

#### Scenario: Loads on startup
- **WHEN** the app launches and a suspended workspaces JSON file exists on disk
- **THEN** the store initializes with all entries from the file

#### Scenario: Survives app restart
- **WHEN** the user suspends a workspace, quits the app, and relaunches
- **THEN** the suspended workspace appears in the store after relaunch

### Requirement: Remove entry by ID
The system SHALL support removing a suspended workspace entry by its ID, permanently deleting it from the store and persisting the change to disk.

#### Scenario: Permanent delete removes from store and disk
- **WHEN** a suspended workspace with ID `xyz-789` is permanently deleted
- **THEN** it no longer appears in the store's entries array and the updated list is persisted to disk

### Requirement: Restore returns snapshot and removes entry
The system SHALL support restoring a suspended workspace by ID, returning its `SessionWorkspaceSnapshot` and removing the entry from the store.

#### Scenario: Restore returns snapshot
- **WHEN** a suspended workspace with ID `xyz-789` is restored
- **THEN** the method returns the `SessionWorkspaceSnapshot` associated with that entry

#### Scenario: Restore removes from store
- **WHEN** a suspended workspace is restored
- **THEN** it no longer appears in the store's entries array and the change is persisted to disk
