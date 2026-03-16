import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

// MARK: - Suspend / Restore Policy Tests

final class TabManagerSuspendRestorePolicyTests: XCTestCase {

    // MARK: - Single-Tab Guard (suspendWorkspace)

    func testShouldAllowSuspendReturnsFalseForSingleTab() {
        XCTAssertFalse(
            TabManager.shouldAllowSuspend(tabCount: 1, hasStore: true),
            "Suspend must be blocked when only one tab remains"
        )
    }

    func testShouldAllowSuspendReturnsFalseForZeroTabs() {
        XCTAssertFalse(
            TabManager.shouldAllowSuspend(tabCount: 0, hasStore: true),
            "Suspend must be blocked with zero tabs"
        )
    }

    func testShouldAllowSuspendReturnsFalseWhenStoreIsMissing() {
        XCTAssertFalse(
            TabManager.shouldAllowSuspend(tabCount: 3, hasStore: false),
            "Suspend must be blocked when suspendedWorkspaceStore is nil"
        )
    }

    func testShouldAllowSuspendReturnsTrueForMultipleTabsWithStore() {
        XCTAssertTrue(
            TabManager.shouldAllowSuspend(tabCount: 2, hasStore: true),
            "Suspend should be allowed with 2+ tabs and an available store"
        )
        XCTAssertTrue(
            TabManager.shouldAllowSuspend(tabCount: 10, hasStore: true)
        )
    }

    // MARK: - Restore Guard

    func testShouldAllowRestoreReturnsFalseWithoutStore() {
        XCTAssertFalse(
            TabManager.shouldAllowRestore(hasStore: false),
            "Restore must be blocked when suspendedWorkspaceStore is nil"
        )
    }

    func testShouldAllowRestoreReturnsTrueWithStore() {
        XCTAssertTrue(
            TabManager.shouldAllowRestore(hasStore: true),
            "Restore should be allowed when store is present"
        )
    }

    // MARK: - Selection Index After Close

    func testSelectionIndexAfterCloseMiddleTab() {
        // Closing tab at index 1 out of 4 → new selection at index 1 (tab that moved up)
        XCTAssertEqual(
            TabManager.selectionIndexAfterClose(closedIndex: 1, tabCount: 4),
            1
        )
    }

    func testSelectionIndexAfterCloseLastTab() {
        // Closing the last tab at index 3 out of 4 → new selection at index 2 (new last)
        XCTAssertEqual(
            TabManager.selectionIndexAfterClose(closedIndex: 3, tabCount: 4),
            2
        )
    }

    func testSelectionIndexAfterCloseFirstTab() {
        // Closing the first tab at index 0 out of 3 → new selection at index 0
        XCTAssertEqual(
            TabManager.selectionIndexAfterClose(closedIndex: 0, tabCount: 3),
            0
        )
    }

    func testSelectionIndexAfterCloseOnlyTwoTabs() {
        // Closing index 0 out of 2 → remaining tab at index 0
        XCTAssertEqual(
            TabManager.selectionIndexAfterClose(closedIndex: 0, tabCount: 2),
            0
        )
        // Closing index 1 out of 2 → remaining tab at index 0
        XCTAssertEqual(
            TabManager.selectionIndexAfterClose(closedIndex: 1, tabCount: 2),
            0
        )
    }

    func testSelectionIndexAfterCloseEdgeCaseSingleTab() {
        // Degenerate: closing the only tab returns 0 (caller should prevent this)
        XCTAssertEqual(
            TabManager.selectionIndexAfterClose(closedIndex: 0, tabCount: 1),
            0
        )
    }
}

// MARK: - SuspendedWorkspaceStore Tests

@MainActor
final class SuspendedWorkspaceStoreLifecycleTests: XCTestCase {

    private func makeStore() -> SuspendedWorkspaceStore {
        // Access the shared instance since init is private.
        // We'll use a dedicated temp file for persistence tests.
        return SuspendedWorkspaceStore.shared
    }

    private func makeWorkspaceSnapshot(
        processTitle: String = "Terminal",
        customTitle: String? = nil,
        customColor: String? = nil,
        isPinned: Bool = false,
        currentDirectory: String = "/tmp"
    ) -> SessionWorkspaceSnapshot {
        SessionWorkspaceSnapshot(
            processTitle: processTitle,
            customTitle: customTitle,
            customColor: customColor,
            isPinned: isPinned,
            currentDirectory: currentDirectory,
            focusedPanelId: nil,
            layout: .pane(SessionPaneLayoutSnapshot(panelIds: [], selectedPanelId: nil)),
            panels: [],
            statusEntries: [],
            logEntries: [],
            progress: nil,
            gitBranch: nil
        )
    }

    private func makeEntry(
        displayName: String = "Test Workspace",
        directory: String? = "/tmp",
        gitBranch: String? = "main",
        snapshot: SessionWorkspaceSnapshot? = nil
    ) -> SuspendedWorkspaceEntry {
        SuspendedWorkspaceEntry(
            id: UUID(),
            originalWorkspaceId: UUID(),
            displayName: displayName,
            directory: directory,
            gitBranch: gitBranch,
            suspendedAt: Date().timeIntervalSince1970,
            snapshot: snapshot ?? makeWorkspaceSnapshot()
        )
    }

    // MARK: - Store Entry Creation / Removal

    func testAddEntryIncreasesCount() {
        let store = makeStore()
        let before = store.entries.count
        store.add(makeEntry())
        XCTAssertEqual(store.entries.count, before + 1)
        // Clean up
        _ = store.remove(id: store.entries.last!.id)
    }

    func testRemoveEntryDecreasesCount() {
        let store = makeStore()
        let entry = makeEntry()
        store.add(entry)
        let countAfterAdd = store.entries.count
        let removed = store.remove(id: entry.id)
        XCTAssertNotNil(removed)
        XCTAssertEqual(store.entries.count, countAfterAdd - 1)
    }

    func testRemoveNonexistentEntryReturnsNil() {
        let store = makeStore()
        let result = store.remove(id: UUID())
        XCTAssertNil(result)
    }

    func testRestoreRemovesEntryFromStore() {
        let store = makeStore()
        let entry = makeEntry()
        store.add(entry)
        let before = store.entries.count
        let restored = store.restore(id: entry.id)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, entry.id)
        XCTAssertEqual(store.entries.count, before - 1)
        // Verify it's gone
        XCTAssertNil(store.entries.first(where: { $0.id == entry.id }))
    }

    func testRestoreNonexistentEntryReturnsNil() {
        let store = makeStore()
        let result = store.restore(id: UUID())
        XCTAssertNil(result)
    }

    func testRemoveAllClearsAllEntries() {
        let store = makeStore()
        let initialCount = store.entries.count
        store.add(makeEntry(displayName: "A"))
        store.add(makeEntry(displayName: "B"))
        store.add(makeEntry(displayName: "C"))
        XCTAssertEqual(store.entries.count, initialCount + 3)
        store.removeAll()
        XCTAssertTrue(store.entries.isEmpty)
    }

    // MARK: - FIFO Eviction

    func testEvictionKeepsMaxEntries() {
        let store = makeStore()
        store.removeAll()
        let maxEntries = SuspendedWorkspaceStore.maxEntries
        // Add maxEntries + 5 entries
        var firstIds: [UUID] = []
        for i in 0..<(maxEntries + 5) {
            let entry = makeEntry(displayName: "Entry \(i)")
            if i < 5 { firstIds.append(entry.id) }
            store.add(entry)
        }
        XCTAssertEqual(store.entries.count, maxEntries, "Store should cap at maxEntries")
        // The first 5 entries should have been evicted (FIFO)
        for id in firstIds {
            XCTAssertNil(
                store.entries.first(where: { $0.id == id }),
                "Oldest entries should be evicted"
            )
        }
        // Clean up
        store.removeAll()
    }

    // MARK: - Snapshot Fidelity

    func testEntryPreservesSnapshotFields() {
        let snapshot = makeWorkspaceSnapshot(
            processTitle: "vim",
            customTitle: "Editor Session",
            customColor: "#FF5733",
            isPinned: true,
            currentDirectory: "/Users/test/project"
        )
        let entry = SuspendedWorkspaceEntry(
            id: UUID(),
            originalWorkspaceId: UUID(),
            displayName: "Editor Session",
            directory: "/Users/test/project",
            gitBranch: "feature/suspend",
            suspendedAt: 1710556800.0,
            snapshot: snapshot
        )

        XCTAssertEqual(entry.displayName, "Editor Session")
        XCTAssertEqual(entry.directory, "/Users/test/project")
        XCTAssertEqual(entry.gitBranch, "feature/suspend")
        XCTAssertEqual(entry.snapshot.processTitle, "vim")
        XCTAssertEqual(entry.snapshot.customTitle, "Editor Session")
        XCTAssertEqual(entry.snapshot.customColor, "#FF5733")
        XCTAssertTrue(entry.snapshot.isPinned)
        XCTAssertEqual(entry.snapshot.currentDirectory, "/Users/test/project")
    }

    func testEntryRoundTripsThroughJSON() throws {
        let panelId = UUID()
        let snapshot = SessionWorkspaceSnapshot(
            processTitle: "zsh",
            customTitle: "Dev Terminal",
            customColor: "#27AE60",
            isPinned: false,
            currentDirectory: "/home/user",
            focusedPanelId: panelId,
            layout: .pane(SessionPaneLayoutSnapshot(panelIds: [panelId], selectedPanelId: panelId)),
            panels: [],
            statusEntries: [],
            logEntries: [],
            progress: nil,
            gitBranch: SessionGitBranchSnapshot(branch: "main", isDirty: true)
        )
        let entry = SuspendedWorkspaceEntry(
            id: UUID(),
            originalWorkspaceId: UUID(),
            displayName: "Dev Terminal",
            directory: "/home/user",
            gitBranch: "main",
            suspendedAt: 1710556800.0,
            snapshot: snapshot
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(entry)
        let decoded = try JSONDecoder().decode(SuspendedWorkspaceEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.originalWorkspaceId, entry.originalWorkspaceId)
        XCTAssertEqual(decoded.displayName, entry.displayName)
        XCTAssertEqual(decoded.directory, entry.directory)
        XCTAssertEqual(decoded.gitBranch, entry.gitBranch)
        XCTAssertEqual(decoded.suspendedAt, entry.suspendedAt, accuracy: 0.001)
        XCTAssertEqual(decoded.snapshot.processTitle, "zsh")
        XCTAssertEqual(decoded.snapshot.customTitle, "Dev Terminal")
        XCTAssertEqual(decoded.snapshot.customColor, "#27AE60")
        XCTAssertEqual(decoded.snapshot.currentDirectory, "/home/user")
        XCTAssertEqual(decoded.snapshot.focusedPanelId, panelId)
        XCTAssertEqual(decoded.snapshot.gitBranch?.branch, "main")
        XCTAssertEqual(decoded.snapshot.gitBranch?.isDirty, true)
    }

    func testEntryWithNilOptionalFieldsRoundTrips() throws {
        let snapshot = makeWorkspaceSnapshot()
        let entry = SuspendedWorkspaceEntry(
            id: UUID(),
            originalWorkspaceId: UUID(),
            displayName: "Untitled",
            directory: nil,
            gitBranch: nil,
            suspendedAt: 1710556800.0,
            snapshot: snapshot
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SuspendedWorkspaceEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertNil(decoded.directory)
        XCTAssertNil(decoded.gitBranch)
        XCTAssertNil(decoded.snapshot.customTitle)
        XCTAssertNil(decoded.snapshot.customColor)
        XCTAssertNil(decoded.snapshot.focusedPanelId)
        XCTAssertNil(decoded.snapshot.gitBranch)
    }

    // MARK: - Persistence Round-Trip via File

    func testPersistenceRoundTripViaFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmux-suspend-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = makeStore()
        store.removeAll()

        let entry1 = makeEntry(displayName: "Session A", directory: "/tmp/a", gitBranch: "main")
        let entry2 = makeEntry(displayName: "Session B", directory: "/tmp/b", gitBranch: "develop")
        store.add(entry1)
        store.add(entry2)

        let fileURL = tempDir.appendingPathComponent("suspended.json")
        XCTAssertTrue(store.save(fileURL: fileURL))

        // Load independently and verify
        let loaded = SuspendedWorkspaceStore.load(fileURL: fileURL)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, 2)
        XCTAssertEqual(loaded?[0].displayName, "Session A")
        XCTAssertEqual(loaded?[0].directory, "/tmp/a")
        XCTAssertEqual(loaded?[0].gitBranch, "main")
        XCTAssertEqual(loaded?[1].displayName, "Session B")
        XCTAssertEqual(loaded?[1].directory, "/tmp/b")
        XCTAssertEqual(loaded?[1].gitBranch, "develop")

        // Clean up shared state
        store.removeAll()
    }

    func testDefaultFileURLSanitizesBundleIdentifier() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmux-suspend-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = SuspendedWorkspaceStore.defaultFileURL(
            bundleIdentifier: "com.example/unsafe id",
            appSupportDirectory: tempDir
        )
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.path.contains("com.example_unsafe_id") == true)
        XCTAssertTrue(url?.path.contains("suspended-workspaces-") == true)
    }

    func testDefaultFileURLFallsThroughToDefaultBundleId() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmux-suspend-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = SuspendedWorkspaceStore.defaultFileURL(
            bundleIdentifier: "   ",
            appSupportDirectory: tempDir
        )
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.path.contains("com.cmuxterm.app") == true)
    }

    // MARK: - Store Add/Restore Integration

    func testAddThenRestoreReturnsSameEntry() {
        let store = makeStore()
        let entry = makeEntry(displayName: "Restorable")
        store.add(entry)

        let restored = store.restore(id: entry.id)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, entry.id)
        XCTAssertEqual(restored?.displayName, "Restorable")
        XCTAssertEqual(restored?.snapshot.processTitle, entry.snapshot.processTitle)

        // Entry should be gone from store
        XCTAssertNil(store.entries.first(where: { $0.id == entry.id }))
    }

    func testRestoreSameEntryTwiceReturnsNilSecondTime() {
        let store = makeStore()
        let entry = makeEntry(displayName: "Once Only")
        store.add(entry)

        let first = store.restore(id: entry.id)
        XCTAssertNotNil(first)

        let second = store.restore(id: entry.id)
        XCTAssertNil(second, "Second restore of the same entry should return nil")
    }

    // MARK: - Ordering / Append Behavior

    func testEntriesAreAppendedInOrder() {
        let store = makeStore()
        let initialCount = store.entries.count

        let entryA = makeEntry(displayName: "A")
        let entryB = makeEntry(displayName: "B")
        let entryC = makeEntry(displayName: "C")
        store.add(entryA)
        store.add(entryB)
        store.add(entryC)

        let tail = Array(store.entries.suffix(3))
        XCTAssertEqual(tail[0].displayName, "A")
        XCTAssertEqual(tail[1].displayName, "B")
        XCTAssertEqual(tail[2].displayName, "C")

        // Clean up
        _ = store.remove(id: entryA.id)
        _ = store.remove(id: entryB.id)
        _ = store.remove(id: entryC.id)
    }

    // MARK: - Entry Identity

    func testEntryIdIsDistinctFromOriginalWorkspaceId() {
        let originalId = UUID()
        let entry = SuspendedWorkspaceEntry(
            id: UUID(),
            originalWorkspaceId: originalId,
            displayName: "Test",
            directory: nil,
            gitBranch: nil,
            suspendedAt: Date().timeIntervalSince1970,
            snapshot: makeWorkspaceSnapshot()
        )
        XCTAssertNotEqual(entry.id, entry.originalWorkspaceId)
    }

    // MARK: - Snapshot with Rich Layout

    func testSnapshotWithPanelLayoutRoundTrips() throws {
        let panelId1 = UUID()
        let panelId2 = UUID()
        let snapshot = SessionWorkspaceSnapshot(
            processTitle: "Terminal",
            customTitle: nil,
            customColor: nil,
            isPinned: false,
            currentDirectory: "/Users/test",
            focusedPanelId: panelId1,
            layout: .pane(SessionPaneLayoutSnapshot(
                panelIds: [panelId1, panelId2],
                selectedPanelId: panelId1
            )),
            panels: [],
            statusEntries: [
                SessionStatusEntrySnapshot(
                    key: "agent",
                    value: "claude",
                    icon: "sparkle",
                    color: "#8E44AD",
                    timestamp: 1710556800.0
                )
            ],
            logEntries: [
                SessionLogEntrySnapshot(
                    message: "Started",
                    level: "info",
                    source: "agent",
                    timestamp: 1710556800.0
                )
            ],
            progress: SessionProgressSnapshot(value: 0.75, label: "Building..."),
            gitBranch: SessionGitBranchSnapshot(branch: "feature/x", isDirty: false)
        )

        let entry = SuspendedWorkspaceEntry(
            id: UUID(),
            originalWorkspaceId: UUID(),
            displayName: "Rich Workspace",
            directory: "/Users/test",
            gitBranch: "feature/x",
            suspendedAt: 1710556800.0,
            snapshot: snapshot
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SuspendedWorkspaceEntry.self, from: data)

        XCTAssertEqual(decoded.snapshot.statusEntries.count, 1)
        XCTAssertEqual(decoded.snapshot.statusEntries.first?.key, "agent")
        XCTAssertEqual(decoded.snapshot.statusEntries.first?.value, "claude")
        XCTAssertEqual(decoded.snapshot.logEntries.count, 1)
        XCTAssertEqual(decoded.snapshot.logEntries.first?.message, "Started")
        XCTAssertEqual(decoded.snapshot.progress?.value, 0.75, accuracy: 0.001)
        XCTAssertEqual(decoded.snapshot.progress?.label, "Building...")
        XCTAssertEqual(decoded.snapshot.gitBranch?.branch, "feature/x")
        XCTAssertEqual(decoded.snapshot.gitBranch?.isDirty, false)

        // Verify layout
        if case .pane(let paneLayout) = decoded.snapshot.layout {
            XCTAssertEqual(paneLayout.panelIds.count, 2)
            XCTAssertEqual(paneLayout.selectedPanelId, panelId1)
        } else {
            XCTFail("Expected pane layout")
        }
    }
}
