import Foundation

// MARK: - Data Model

struct SuspendedWorkspaceEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let originalWorkspaceId: UUID
    let displayName: String
    let directory: String?
    let gitBranch: String?
    let suspendedAt: TimeInterval
    let snapshot: SessionWorkspaceSnapshot
}

// MARK: - Persistence Envelope

private struct SuspendedWorkspacesEnvelope: Codable, Sendable {
    static let currentVersion = 1

    var version: Int
    var entries: [SuspendedWorkspaceEntry]
}

// MARK: - Store

@MainActor
final class SuspendedWorkspaceStore: ObservableObject {

    static let shared = SuspendedWorkspaceStore()

    static let maxEntries = 50

    @Published private(set) var entries: [SuspendedWorkspaceEntry] = []

    private init() {
        entries = Self.load() ?? []
    }

    // MARK: - Public API

    /// Suspends a workspace by adding its snapshot to the store.
    /// If the store exceeds `maxEntries`, the oldest entries are evicted (FIFO).
    func add(_ entry: SuspendedWorkspaceEntry) {
        entries.append(entry)
        evictIfNeeded()
        save()
    }

    /// Removes the entry with the given identifier.
    @discardableResult
    func remove(id: UUID) -> SuspendedWorkspaceEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = entries.remove(at: index)
        save()
        return removed
    }

    /// Restores (removes and returns) the entry with the given identifier.
    /// The caller is responsible for rebuilding the workspace from the returned snapshot.
    func restore(id: UUID) -> SuspendedWorkspaceEntry? {
        return remove(id: id)
    }

    /// Removes all suspended workspace entries and persists the change.
    func removeAll() {
        guard !entries.isEmpty else { return }
        entries.removeAll()
        save()
    }

    // MARK: - FIFO Eviction

    private func evictIfNeeded() {
        guard entries.count > Self.maxEntries else { return }
        let overflow = entries.count - Self.maxEntries
        entries.removeFirst(overflow)
    }

    // MARK: - Persistence

    @discardableResult
    func save(fileURL: URL? = nil) -> Bool {
        guard let fileURL = fileURL ?? Self.defaultFileURL() else { return false }
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let envelope = SuspendedWorkspacesEnvelope(
                version: SuspendedWorkspacesEnvelope.currentVersion,
                entries: entries
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(envelope)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load(fileURL: URL? = nil) -> [SuspendedWorkspaceEntry]? {
        guard let fileURL = fileURL ?? defaultFileURL() else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(SuspendedWorkspacesEnvelope.self, from: data) else { return nil }
        guard envelope.version == SuspendedWorkspacesEnvelope.currentVersion else { return nil }
        return envelope.entries
    }

    static func defaultFileURL(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        appSupportDirectory: URL? = nil
    ) -> URL? {
        let resolvedAppSupport: URL
        if let appSupportDirectory {
            resolvedAppSupport = appSupportDirectory
        } else if let discovered = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            resolvedAppSupport = discovered
        } else {
            return nil
        }
        let bundleId = (bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? bundleIdentifier!
            : "com.cmuxterm.app"
        let safeBundleId = bundleId.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "_",
            options: .regularExpression
        )
        return resolvedAppSupport
            .appendingPathComponent("cmux", isDirectory: true)
            .appendingPathComponent("suspended-workspaces-\(safeBundleId).json", isDirectory: false)
    }
}
