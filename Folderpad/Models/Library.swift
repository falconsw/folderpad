import AppKit
import Observation

enum LibrarySheet: String, Identifiable {
    case newGroup
    case suggestions

    var id: String { rawValue }
}

/// Groups, installed apps and the Dock, as one model for every window and menu.
@Observable
final class Library {
    static let shared = Library()

    private(set) var groups: [AppGroup] = []
    private(set) var apps: [InstalledApp] = []
    /// Everything after the Dock's divider, in Dock order.
    private(set) var dockItems: [DockItem] = []
    /// Groups shown in the Dock, keyed by group id, with how the Dock shows them.
    private(set) var dockStyles: [String: DockStyle] = [:]
    private(set) var isScanning = false
    private(set) var location: GroupsLocation

    var error: String?
    var sheet: LibrarySheet?
    /// Apps waiting for the New Group sheet to put them in the group it creates.
    var pendingApps: [URL] = []
    var groupToRename: AppGroup?
    var groupToDelete: AppGroup?

    private var store: GroupStore { GroupStore(root: location.url) }
    private var pendingDockRestart: Task<Void, Never>?
    private var lastScan: Date?
    private var appearanceObservation: NSKeyValueObservation?

    private init() {
        location = .current
        reload()
        Task { await scanApps() }
        observeAppearance()
    }

    // MARK: Reading

    /// Rereads the group folders and the Dock, which may have changed in Finder or the Dock itself.
    func reload() {
        groups = store.groups()
        dockItems = DockTiles.items(in: Dock.tiles())
        var styles: [String: DockStyle] = [:]
        for item in dockItems where item.kind == .folder {
            styles[item.id] = item.style
        }
        dockStyles = styles.filter { id, _ in groups.contains { $0.id == id } }
    }

    func scanApps() async {
        isScanning = true
        apps = await Task.detached(priority: .userInitiated) { AppCatalog.scan() }.value
        isScanning = false
        lastScan = .now
    }

    /// Picks up apps installed or removed while Folderpad was in the background.
    func rescanIfStale() {
        guard !isScanning, (lastScan?.timeIntervalSinceNow ?? -.infinity) < -30 else { return }
        Task { await scanApps() }
    }

    func group(withID id: String) -> AppGroup? {
        groups.first { $0.id == id }
    }

    /// Names of the groups each app is in, keyed by the app's id.
    var memberships: [String: [String]] {
        var result: [String: [String]] = [:]
        for group in groups {
            for item in group.items {
                if let target = item.target { result[target.pathKey, default: []].append(group.name) }
            }
        }
        return result
    }

    func setLocation(_ location: GroupsLocation) {
        self.location = location
        UserDefaults.standard.set(location.rawValue, forKey: Pref.location)
        reload()
    }

    // MARK: Groups

    @discardableResult
    func createGroup(named name: String, apps: [URL] = [], inDock: Bool) -> AppGroup? {
        do {
            let folder = try store.createGroup(named: name)
            for app in apps { try store.add(app, to: folder) }
            refreshIcon(of: folder)
            if inDock {
                Dock.save(DockTiles.setting(folder, style: Pref.newGroupStyle, in: Dock.tiles()))
                Dock.restart()
            }
            reload()
            return group(withID: folder.pathKey)
        } catch {
            fail(error)
            return nil
        }
    }

    /// Returns the renamed group's id.
    @discardableResult
    func rename(_ group: AppGroup, to name: String) -> String? {
        do {
            let folder = try store.rename(group.folder, to: name)
            if dockStyles[group.id] != nil {
                Dock.save(DockTiles.moving(group.folder, to: folder, in: Dock.tiles()))
                Dock.restart()
            }
            reload()
            return folder.pathKey
        } catch {
            fail(error)
            return nil
        }
    }

    func delete(_ group: AppGroup) {
        do {
            try store.trash(group.folder)
            if dockStyles[group.id] != nil {
                Dock.save(DockTiles.removing(group.folder, from: Dock.tiles()))
                Dock.restart()
            }
        } catch {
            fail(error)
        }
        reload()
    }

    func add(_ urls: [URL], to group: AppGroup) {
        let apps = urls.filter { $0.pathExtension.lowercased() == "app" }
        guard !apps.isEmpty else { return }
        do {
            for app in apps { try store.add(app, to: group.folder) }
        } catch {
            fail(error)
        }
        contentsChanged(group)
    }

    func remove(_ items: [GroupItem], from group: AppGroup) {
        do {
            for item in items { try store.remove(item) }
        } catch {
            fail(error)
        }
        contentsChanged(group)
    }

    /// Creates the accepted suggestions (or fills existing groups of the same name) and
    /// restarts the Dock once at the end.
    func apply(_ suggestions: [GroupSuggestion], inDock: Bool) {
        var tiles = Dock.tiles()
        for suggestion in suggestions where !suggestion.apps.isEmpty {
            do {
                let folder: URL
                if let existing = groups.first(where: { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }) {
                    folder = existing.folder
                } else {
                    folder = try store.createGroup(named: suggestion.name)
                }
                for app in suggestion.apps { try store.add(app.url, to: folder) }
                GroupStore.setMarker(on: folder)
                refreshIcon(of: folder)
                if inDock, DockTiles.index(of: folder, in: tiles) == nil {
                    tiles = DockTiles.setting(folder, style: Pref.newGroupStyle, in: tiles)
                }
            } catch {
                fail(error)
            }
        }
        if inDock {
            Dock.save(tiles)
            Dock.restart()
        }
        reload()
    }

    // MARK: Dock

    func setInDock(_ group: AppGroup, _ inDock: Bool) {
        if inDock {
            GroupStore.setMarker(on: group.folder)
            refreshIcon(of: group.folder)
            Dock.save(DockTiles.setting(group.folder, style: Pref.newGroupStyle, in: Dock.tiles()))
        } else {
            Dock.save(DockTiles.removing(group.folder, from: Dock.tiles()))
        }
        restartDockNow()
    }

    /// Restyles a folder tile, whether it is a group or any other folder.
    func setDockStyle(_ style: DockStyle, for folder: URL) {
        Dock.save(DockTiles.setting(folder, style: style, in: Dock.tiles()))
        reload()
        // Picking several options in a row restarts the Dock once.
        scheduleDockRestart()
    }

    /// Pins folders after the Dock's divider. Groups get their icon refreshed first.
    func pinToDock(_ folders: [URL]) {
        var tiles = Dock.tiles()
        for folder in folders where DockTiles.index(of: folder, in: tiles) == nil {
            if let group = group(withID: folder.pathKey) {
                GroupStore.setMarker(on: group.folder)
                refreshIcon(of: group.folder)
            }
            tiles = DockTiles.setting(folder, style: Pref.newGroupStyle, in: tiles)
        }
        Dock.save(tiles)
        restartDockNow()
    }

    func removeFromDock(_ item: DockItem) {
        Dock.save(DockTiles.removing(id: item.id, from: Dock.tiles()))
        restartDockNow()
    }

    /// Reorders the tiles after the divider, as dragged in the sidebar.
    func moveDockItems(from source: IndexSet, to destination: Int) {
        var ids = dockItems.map(\.id)
        let moving = source.map { ids[$0] }
        let insertAt = destination - source.filter { $0 < destination }.count
        ids = ids.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        ids.insert(contentsOf: moving, at: insertAt)
        Dock.save(DockTiles.reordered(Dock.tiles(), ids: ids))
        restartDockNow()
    }

    // MARK: Helpers

    private func contentsChanged(_ group: AppGroup) {
        // Marked, the group stays a group even if its last app is removed.
        GroupStore.setMarker(on: group.folder)
        refreshIcon(of: group.folder)
        reload()
        // A stack follows the folder live; a folder icon is only redrawn when the Dock restarts.
        if dockStyles[group.id]?.display == .folder { scheduleDockRestart() }
    }

    private func refreshIcon(of folder: URL) {
        FolderIcon.apply(to: folder, apps: store.items(in: folder).compactMap(\.target))
    }

    // MARK: Appearance

    /// Redraws the group folder icons when the system switches between light and dark.
    private func observeAppearance() {
        reconcileIconAppearance()
        guard let app = NSApp else { return }
        appearanceObservation = app.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.reconcileIconAppearance() }
        }
    }

    /// Rebakes the group folder icons when the current appearance differs from the one they
    /// were last baked in, so a dark-mode Mac shows dark tiles even on the first launch.
    private func reconcileIconAppearance() {
        let now = FolderIcon.systemIsDark ? "dark" : "light"
        guard UserDefaults.standard.string(forKey: Pref.bakedIconAppearance) != now else { return }
        Icons.clear()
        for group in groups { refreshIcon(of: group.folder) }
        UserDefaults.standard.set(now, forKey: Pref.bakedIconAppearance)
        // A folder shows its baked icon only after the Dock restarts; a stack follows live.
        if dockStyles.values.contains(where: { $0.display == .folder }) { scheduleDockRestart() }
    }

    private func restartDockNow() {
        pendingDockRestart?.cancel()
        Dock.restart()
        reload()
    }

    private func scheduleDockRestart() {
        pendingDockRestart?.cancel()
        pendingDockRestart = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            Dock.restart()
        }
    }

    private func fail(_ error: Error) {
        self.error = error.localizedDescription
    }
}
