## Context

cmux is a native macOS terminal app (Swift/AppKit) built on libghostty. It organizes terminal sessions as "workspaces" displayed in a vertical sidebar. Each workspace can contain multiple terminal panels, browser panels, and markdown panels arranged in a split layout.

Current state:
- **Session persistence** already exists (`SessionPersistence.swift`): full app state is saved on quit and restored on launch. This includes scrollback text, panel layout, git branches, notifications, and browser URLs.
- **Workspace close** (`TabManager.closeWorkspace()`) permanently destroys the workspace — panels are torn down, notifications cleared, state lost.
- **Snapshot infrastructure** is mature: `SessionWorkspaceSnapshot` captures everything needed to reconstruct a workspace. `Workspace.sessionSnapshot()` and `Workspace.restoreSessionSnapshot()` are production-tested.
- **TabManager** manages the workspace list per window, with support for pinning, reordering, drag-and-drop, and cross-window moves via `detachWorkspace()`/`attachWorkspace()`.

Key constraints from CLAUDE.md:
- Never break typing-latency-sensitive paths (TabItemView, hitTest, forceRefresh)
- All UI strings must be localized with `String(localized:defaultValue:)`
- Tests must verify runtime behavior, not source shape
- Socket commands must not steal focus

## Goals / Non-Goals

**Goals:**
- Allow workspaces to be "suspended" — snapshot state before teardown, persist to disk
- Provide a sidebar UI to browse and restore suspended workspaces
- Integrate with the command palette for quick restore via fuzzy search
- Persist suspended workspaces across app quit/restart
- Support permanent deletion of suspended workspaces
- Keep the feature lightweight — no extra processes, no background terminals

**Non-Goals:**
- Running terminals in the background (like tmux/Zellij detach) — suspended workspaces are snapshots, not live processes
- Sharing suspended workspaces across machines or exporting them
- Auto-suspending idle workspaces (manual action only, for now)
- Socket API / CLI commands (can be added later)
- Undo for permanent close (once hard-deleted, it's gone)

## Decisions

### 1. Suspended workspaces are snapshots, not live processes

**Decision**: When a workspace is suspended, we take a `SessionWorkspaceSnapshot` (including scrollback) and tear down the live terminal surfaces. Restoration creates fresh terminal processes and replays scrollback via the existing `SessionScrollbackReplayStore` mechanism.

**Alternatives considered**:
- *Keep terminal processes alive in background*: Would consume significant resources (memory, PTY file descriptors) and add complexity. cmux is a native app, not a terminal multiplexer daemon.
- *Save only metadata (name/branch/dir)*: Too lossy — users want scrollback and panel layout preserved.

**Rationale**: The existing session restore infrastructure proves this approach works well. Users already experience it on app restart. The scrollback replay gives a good-enough approximation.

### 2. Separate storage file for suspended workspaces

**Decision**: Suspended workspaces are stored in `Application Support/cmux/suspended-workspaces-<bundleId>.json`, separate from the main session file.

**Alternatives considered**:
- *Embed in `AppSessionSnapshot`*: Would couple suspended state to the autosave cycle and version schema. Adding a `suspended` field to the existing snapshot would require schema migration.
- *One file per suspended workspace*: More complex filesystem management for minimal benefit.

**Rationale**: Separate file keeps concerns isolated. The main session file captures live state; the suspended file captures archived state. They evolve independently.

### 3. Suspend replaces soft close; permanent close is opt-in

**Decision**: The default "close workspace" action (Cmd+W on workspace / sidebar close button) becomes "suspend" when the workspace has meaningful state (terminal has output). A "Close Permanently" option is available in the context menu and via a modifier (Option+click close button). When there's only one workspace, close is blocked (existing behavior).

**Alternatives considered**:
- *Always suspend, never permanently close via UI*: Users need a way to clean up; would accumulate junk.
- *Add a separate "Suspend" action, keep close as-is*: More discoverable but adds cognitive load. Users would forget to use suspend.
- *Ask every time (dialog)*: Too disruptive for a frequent action.

**Rationale**: Making suspend the default ensures state is never accidentally lost. Power users who want a clean close can use the permanent option.

### 4. Sidebar section for suspended workspaces

**Decision**: A collapsible "Suspended" section appears below the active workspace list in the sidebar, separated by a subtle divider. Each suspended workspace shows its name/title, git branch, and how long ago it was suspended. Clicking restores it. A trailing "×" button or context menu allows permanent deletion.

**Alternatives considered**:
- *Popover/dropdown button*: Requires an extra click to see what's available. Less discoverable.
- *Separate panel/window*: Overkill for a list of snapshots.
- *Command palette only*: Not discoverable enough for a core feature.

**Rationale**: Inline in the sidebar keeps it visible and one-click-away. The collapsible section avoids clutter when there are no suspended workspaces.

### 5. SuspendedWorkspaceStore as an ObservableObject

**Decision**: A new `SuspendedWorkspaceStore` class (ObservableObject) manages the list of suspended workspace entries. It's owned by AppDelegate (like `notificationStore`) and injected via `.environmentObject()`.

**Rationale**: Follows the existing pattern (TabManager, NotificationStore are ObservableObjects). Allows the sidebar to reactively update when workspaces are suspended/restored.

### 6. Maximum 50 suspended workspaces, FIFO eviction

**Decision**: Cap at 50 suspended workspaces. When the limit is exceeded, the oldest suspended workspace is permanently deleted. This prevents unbounded disk growth.

**Rationale**: 50 is generous for any realistic workflow. Scrollback at max (400KB per workspace) × 50 = 20MB worst case, acceptable.

## Risks / Trade-offs

- **[Risk] Disk usage growth** → Mitigation: 50-workspace cap, existing scrollback truncation (400K chars). Worst case ~20MB.
- **[Risk] Restore fidelity** → Mitigation: Uses the same restore path as app restart, which is already production-tested. Shell processes will be restarted (new shell in the same directory), not resumed.
- **[Risk] Sidebar clutter with many suspended workspaces** → Mitigation: Section is collapsible and starts collapsed when empty. Shows count badge.
- **[Risk] Performance of sidebar with suspended section** → Mitigation: Suspended items are simpler than active TabItemView (no real-time updates, no notification tracking). LazyVStack handles large lists efficiently.
- **[Trade-off] Suspend is lossy** → Terminal process state (running commands, SSH sessions) is lost. Only scrollback text, layout, and metadata survive. This is documented and expected — same as app restart behavior.
