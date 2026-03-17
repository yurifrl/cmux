# Session Restore Feature — Discovery Log

## 2026-03-16: Initial Exploration

### Goal
Add "soft close" for workspaces in cmux. When a workspace is closed, it becomes "suspended" — 
its state is saved and it appears in a UI dropdown for restoration. Users can also "hard close" 
to permanently destroy a suspended workspace.

### Key Discoveries

#### 1. cmux Already Has Session Persistence
- `Sources/SessionPersistence.swift` (470 lines) — full snapshot model
- Autosaves every 8 seconds (`SessionPersistencePolicy.autosaveInterval`)
- On quit, saves ALL workspace state (terminals, browsers, splits, scrollback)
- On launch, restores everything
- Snapshot structs: `AppSessionSnapshot` → `SessionWindowSnapshot` → `SessionTabManagerSnapshot` → `SessionWorkspaceSnapshot`
- Each workspace snapshot has: panels, layout, git branch, scrollback text, notifications, progress, etc.
- **Key insight**: The snapshot infrastructure already captures everything we need for suspended workspaces

#### 2. Architecture Overview
- **TabManager** (`Sources/TabManager.swift`, ~4090 lines) — manages workspace list per window
  - `tabs: [Workspace]` — the active workspace list
  - `closeWorkspace()` — tears down panels, removes from list, clears notifications
  - `detachWorkspace()` / `attachWorkspace()` — already exists for cross-window moves
  - Has pinning support (`isPinned`, `setPinned`)
- **Workspace** (`Sources/Workspace.swift`, ~4968 lines) — single workspace with panels/splits
  - `sessionSnapshot()` / `restoreSessionSnapshot()` — already exists
  - `teardownAllPanels()` — called on close
- **ContentView** (`Sources/ContentView.swift`, ~12886 lines) — sidebar + workspace rendering
  - `TabItemView` — renders each workspace in sidebar
  - `SidebarState` — sidebar visibility/width
  - Has command palette infrastructure (fuzzy search, results, actions)

#### 3. Zellij Session Model (Reference)
- `zellij list-sessions` — shows named sessions with creation time
- `zellij attach <name>` — reattach to a session
- `zellij kill-session` / `zellij delete-session` — permanent close
- Sessions persist even when you detach/close the terminal
- **Key difference**: Zellij sessions are separate processes; cmux workspaces are in-app

#### 4. What Currently Happens on Close
In `TabManager.closeWorkspace()`:
1. Removes from `tabs` array
2. Clears notifications
3. Calls `workspace.teardownAllPanels()` — destroys terminal surfaces
4. Removes ownership
5. **State is lost forever** — no snapshot is taken before destruction

#### 5. Session Persistence Store
- `SessionPersistenceStore.save()` / `.load()` — file-based JSON persistence
- Stores at `Application Support/cmux/session.json` (presumably)
- Already handles scrollback truncation (4000 lines / 400K chars)
- Already handles ANSI escape sequence boundary safety

### Architecture Plan

#### Core Concept: "Suspended Workspaces"
When a workspace is "soft closed":
1. Take a `SessionWorkspaceSnapshot` of the workspace
2. Store it in a new `SuspendedWorkspaceStore` 
3. Tear down the live workspace (free terminal surfaces)
4. The snapshot persists on disk

When restored:
1. Create a new workspace
2. Call `restoreSessionSnapshot()` with the saved snapshot
3. Remove from suspended store

#### Components to Build

**1. SuspendedWorkspaceStore** (new file)
- Manages a list of `SuspendedWorkspace` entries
- Each entry: snapshot + metadata (name, suspended date, git branch, directory)
- Persists to disk (JSON, separate from main session file)
- Observable for UI updates

**2. TabManager Changes**
- New `suspendWorkspace()` method — snapshots then closes
- Modify `closeWorkspace()` to optionally suspend instead of destroy
- New `restoreWorkspace(id:)` — restores from suspended store

**3. Sidebar UI — Suspended Workspace Dropdown**
- Button/section in sidebar showing suspended count
- Dropdown/popover listing suspended workspaces with metadata
- Each entry: name, branch, directory, suspended time ago
- Click to restore, swipe/button to permanently delete

**4. Command Palette Integration**
- "Restore Workspace" command in command palette
- Lists suspended workspaces as search results

**5. Socket API / CLI**
- `workspace.suspend` — suspend current/specified workspace
- `workspace.list-suspended` — list suspended workspaces
- `workspace.restore` — restore a suspended workspace

### File Impact Assessment
- **New**: `Sources/SuspendedWorkspaceStore.swift`
- **Modify**: `Sources/TabManager.swift` — suspend/restore methods
- **Modify**: `Sources/ContentView.swift` — sidebar UI for suspended workspaces
- **Modify**: `Sources/SessionPersistence.swift` — suspended workspace snapshot model
- **Modify**: `Sources/AppDelegate.swift` — wire up store, autosave suspended state
- **Maybe**: `Sources/SocketControlSettings.swift` — CLI commands
- **Maybe**: `CLI/cmux.swift` — CLI subcommands

### Open Questions
1. Should suspended workspaces survive app quit/restart? → YES, persist to disk
2. Max number of suspended workspaces? → Start with 50
3. Should there be a keyboard shortcut for suspend? → Yes, e.g. Cmd+Shift+W
4. Should the last workspace be suspendable? → No, always keep at least one live workspace
5. Where in the sidebar should the restore UI live? → Bottom of workspace list or a dedicated section

### Risks
- Large scrollback in suspended workspaces could balloon disk usage
- Need to handle the case where a suspended workspace's terminal state can't be fully restored
- Must not break existing session persistence (autosave every 8s)
- Must respect the typing-latency-sensitive paths noted in CLAUDE.md
- UI must follow localization requirements (all strings localized)

---

## 2026-03-16: Implementation Complete

### What Was Built

**New file: `Sources/SuspendedWorkspaceStore.swift`** (130 lines)
- `SuspendedWorkspaceEntry` — Codable struct with id, originalWorkspaceId, displayName, directory, gitBranch, suspendedAt, snapshot
- `SuspendedWorkspacesEnvelope` — versioned wrapper for JSON persistence
- `SuspendedWorkspaceStore` — @MainActor ObservableObject with add/remove/restore/removeAll/save/load
- FIFO eviction at 50 entries
- Persistence to `Application Support/cmux/suspended-workspaces-<bundleId>.json`
- Follows exact same pattern as `SessionPersistenceStore`

**Modified: `Sources/TabManager.swift`** (+103 lines)
- `weak var suspendedWorkspaceStore: SuspendedWorkspaceStore?` property
- `suspendWorkspace(_:)` — snapshots with scrollback, creates entry, adds to store, closes
- `restoreWorkspace(entryId:)` — creates new Workspace, restores snapshot, attaches, selects
- `permanentlyCloseWorkspace(_:)` — semantic alias for closeWorkspace
- Static helper methods for testability: `shouldAllowSuspend`, `shouldAllowRestore`, `selectionIndexAfterClose`
- Modified `closeWorkspaceIfRunningProcess` to suspend by default when workspace has meaningful state

**Modified: `Sources/Workspace.swift`** (+36 lines)
- `hasMeaningfulState` computed property — checks customTitle, customColor, isPinned, statusEntries, logEntries, gitBranch, multiple panels, live surfaces, running processes, non-default titles

**Modified: `Sources/ContentView.swift`** (+260 lines)
- `SuspendedWorkspaceSidebarSection` — collapsible section below active workspaces
- `SuspendedWorkspaceRow` — moon.zzz icon, name, branch/dir subtitle, relative time, hover × delete
- Context menu: "Suspend Workspace" and "Close Permanently" on active workspace rows
- `suspendTabs()` helper for multi-select suspend
- Command palette: "Suspend Workspace" and "Restore Suspended Workspace" commands with handlers
- Collapse state persisted via `@AppStorage("suspendedSectionCollapsed")`

**Modified: `Sources/KeyboardShortcutSettings.swift`** (+6 lines)
- `.suspendWorkspace` action with default Cmd+Shift+W

**Modified: `Sources/AppDelegate.swift`** (+5 lines)
- Store wired in `applicationWillTerminate` (final save)
- Store wired in window creation (environmentObject + TabManager property)

**Modified: `Sources/cmuxApp.swift`** (+2 lines)
- `@StateObject` for SuspendedWorkspaceStore.shared + environmentObject injection

### Implementation Decisions Made During Coding
1. Used `SuspendedWorkspaceStore.shared` singleton pattern (matches how the store needs to be shared across windows)
2. `SuspendedWorkspaceRow` uses `RelativeDateTimeFormatter` with `.abbreviated` style for time display
3. Entries listed most-recent-first via `.reversed()` in the UI
4. "Clear All" button in the suspended section header (bonus feature)
5. Command palette "Restore" restores the most recently suspended workspace (simplest UX)
6. `hasMeaningfulState` is intentionally broad — better to preserve too much than lose state

### Remaining Minor Items
- Task 4.4 (Option+click close button for permanent close) — deferred, requires detecting modifier flags in the SwiftUI button action which is non-trivial in this architecture
- Task 6.1 (max workspace limit guard) — deferred, the 128-workspace limit is practically unreachable

---

## 2026-03-17: Architecture Pivot — Live Process Persistence Required

### The Problem
The snapshot-based approach (v1) doesn't meet the user's core need. They want Zellij-style sessions: 
**close a workspace, come back later, processes are still running.**

Current implementation only preserves scrollback text and layout — running processes are killed on suspend.

### Why This Is Hard
cmux terminals are created through libghostty (`ghostty_surface_new`), which manages its own PTY. 
Each `GhosttySurfaceView` owns a ghostty surface that directly holds the PTY file descriptor.
There is no intermediate mux layer.

### Possible Approaches

#### A: Wrap terminals in tmux/zellij sessions (most pragmatic)
- Each workspace spawns its terminals inside a tmux/zellij session
- "Suspend" = detach from the mux session, destroy the ghostty surfaces
- "Restore" = reattach to the mux session, create new ghostty surfaces connected to existing PTYs
- **Pros**: Leverages battle-tested mux; processes survive; scrollback preserved
- **Cons**: Dependency on tmux/zellij; need to bridge ghostty surface ↔ mux PTY; 
  tmux's own UI (status bar, key bindings) would need to be suppressed

#### B: Use abduco/dtach as minimal PTY wrapper
- Lighter than tmux — just PTY persistence, no windowing
- Each terminal panel runs through abduco which holds the PTY
- "Suspend" = disconnect from abduco socket
- "Restore" = reconnect to abduco socket
- **Pros**: Minimal, no UI conflicts
- **Cons**: Less mature; still need to bridge ghostty ↔ external PTY

#### C: Build a custom PTY daemon (cmuxd already exists)
- cmuxd already exists in the repo as a Zig binary
- Could extend it to hold PTYs and forward I/O to ghostty surfaces
- "Suspend" = cmuxd keeps PTY alive, ghostty surface destroyed
- "Restore" = new ghostty surface connects to cmuxd-held PTY
- **Pros**: Full control; no external deps; already have the daemon
- **Cons**: Significant engineering; PTY forwarding is complex

#### D: Use ghostty's own multiplexing (if it exists)
- Ghostty may have built-in mux support (it's based on libvaxis concepts)
- Need to investigate ghostty's source for session/mux capabilities
- **Pros**: Native integration
- **Cons**: May not exist; upstream dependency

### Recommendation
Approach A (tmux) or C (cmuxd) are most viable. Need to investigate cmuxd's current capabilities
and whether ghostty surfaces can be reconnected to existing PTYs.

### Next Steps
1. Investigate cmuxd — what does it do currently?
2. Investigate ghostty surface lifecycle — can a surface be created and connected to an existing PTY?
3. Decide on approach based on findings
