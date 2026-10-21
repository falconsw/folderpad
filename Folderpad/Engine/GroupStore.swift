import Foundation

/// Reads and writes group folders under one root (normally /Applications).
///
/// A group is a plain folder of Finder aliases, so Finder and the Dock show it without
/// Folderpad running, and it keeps working if Folderpad is removed. Nothing here ever
/// moves or deletes an app: only aliases and the folders that hold them.
nonisolated struct GroupStore: Sendable {
    let root: URL

    enum Failure: LocalizedError {
        case emptyName
        case invalidName(String)
        case exists(String)
        case notAGroup(String)

        var errorDescription: String? {
            switch self {
            case .emptyName:
                "Give the group a name."
            case .invalidName(let name):
                "“\(name)” can't be used as a group name."
            case .exists(let name):
                "There is already something called “\(name)” in that folder."
            case .notAGroup(let name):
                "“\(name)” holds more than app aliases, so Folderpad won't delete it."
            }
        }
    }

    /// Extended attribute on folders Folderpad made or edited, so an empty group still counts.
    static let marker = "com.falconsw.folderpad.group"

    // MARK: Reading

    /// Every group folder directly under the root, sorted by name.
    func groups() -> [AppGroup] {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return children
            .filter(isGroupFolder)
            .map { AppGroup(folder: $0, items: items(in: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A folder Folderpad marked, or one holding nothing but app aliases. The second rule
    /// picks up folders people built by hand in Finder, while leaving Utilities and
    /// vendor folders (which hold real apps) alone.
    func isGroupFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
        guard values?.isDirectory == true, values?.isPackage == false, values?.isSymbolicLink == false else {
            return false
        }
        if Self.hasMarker(url) { return true }
        let entries = visibleEntries(of: url)
        return !entries.isEmpty && entries.allSatisfy(isAppAlias)
    }

    func items(in folder: URL) -> [GroupItem] {
        visibleEntries(of: folder)
            .filter(isAppAlias)
            .map { alias in
                var name = alias.lastPathComponent
                if name.lowercased().hasSuffix(".app") { name.removeLast(4) }
                return GroupItem(aliasURL: alias, target: Self.resolve(alias), name: name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A Finder alias or symlink that points (or pointed) at an app.
    func isAppAlias(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey])
        guard values?.isAliasFile == true || values?.isSymbolicLink == true else { return false }
        if url.pathExtension.lowercased() == "app" { return true }
        return Self.resolve(url)?.pathExtension.lowercased() == "app"
    }

    /// Where an alias leads, if that file still exists.
    static func resolve(_ alias: URL) -> URL? {
        let isLink = (try? alias.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
        let target = isLink
            ? alias.resolvingSymlinksInPath()
            : try? URL(resolvingAliasFileAt: alias, options: [.withoutUI, .withoutMounting])
        guard let target, target != alias, FileManager.default.fileExists(atPath: target.path) else { return nil }
        return target
    }

    // MARK: Writing

    @discardableResult
    func createGroup(named rawName: String) throws -> URL {
        let name = try Self.validated(rawName)
        let folder = root.appendingPathComponent(name, isDirectory: true)
        guard !Self.somethingExists(at: folder) else { throw Failure.exists(name) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Self.setMarker(on: folder)
        return folder
    }

    /// Adds a Finder alias to the app, named the way Finder names the app. Returns nil when
    /// the group already holds the app.
    @discardableResult
    func add(_ app: URL, to folder: URL) throws -> URL? {
        let target = app.resolvingSymlinksInPath()
        guard !items(in: folder).contains(where: { $0.target?.pathKey == target.pathKey }) else { return nil }

        var name = FileManager.default.displayName(atPath: target.path)
        if name.lowercased().hasSuffix(".app") { name.removeLast(4) }
        let alias = Self.unusedURL(in: folder, name: name.replacingOccurrences(of: "/", with: "-"))

        let bookmark = try target.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(bookmark, to: alias)
        // Finder and the Dock then show "Cursor" rather than "Cursor.app".
        var values = URLResourceValues()
        values.hasHiddenExtension = true
        var hidden = alias
        try? hidden.setResourceValues(values)
        return alias
    }

    /// Deletes the alias. The app it points to is untouched.
    func remove(_ item: GroupItem) throws {
        guard isAppAlias(item.aliasURL) else { return }
        try FileManager.default.removeItem(at: item.aliasURL)
    }

    func rename(_ folder: URL, to rawName: String) throws -> URL {
        let name = try Self.validated(rawName)
        guard name != folder.lastPathComponent else { return folder }
        let destination = folder.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
        // A change of case only ("ide" → "IDE") is the same file on a case-insensitive disk.
        let caseOnly = name.lowercased() == folder.lastPathComponent.lowercased()
        guard caseOnly || !Self.somethingExists(at: destination) else { throw Failure.exists(name) }
        try FileManager.default.moveItem(at: folder, to: destination)
        return destination
    }

    /// Moves the group folder to the Trash, refusing if anything but app aliases is inside.
    func trash(_ folder: URL) throws {
        guard visibleEntries(of: folder).allSatisfy(isAppAlias) else {
            throw Failure.notAGroup(folder.lastPathComponent)
        }
        try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
    }

    // MARK: Helpers

    static func validated(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw Failure.emptyName }
        guard !name.hasPrefix("."), !name.contains("/"), !name.contains(":"),
              !name.lowercased().hasSuffix(".app"), name.utf8.count <= 255 else {
            throw Failure.invalidName(name)
        }
        return name
    }

    static func setMarker(on folder: URL) {
        let value = Array("1".utf8)
        _ = folder.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return setxattr(path, marker, value, value.count, 0, 0)
        }
    }

    static func hasMarker(_ folder: URL) -> Bool {
        folder.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return getxattr(path, marker, nil, 0, 0, 0) >= 0
        }
    }

    /// Entries Finder shows: no dotfiles, no custom-icon file (`Icon\r`).
    private func visibleEntries(of folder: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isHiddenKey, .isAliasFileKey, .isSymbolicLinkKey], options: []
        )) ?? []
        return entries.filter { entry in
            let name = entry.lastPathComponent
            guard !name.hasPrefix("."), name != "Icon\r" else { return false }
            return (try? entry.resourceValues(forKeys: [.isHiddenKey]))?.isHidden != true
        }
    }

    /// Also true for a broken symlink, which `fileExists` reports as missing.
    private static func somethingExists(at url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }

    private static func unusedURL(in folder: URL, name: String) -> URL {
        var candidate = folder.appendingPathComponent("\(name).app")
        var number = 2
        while somethingExists(at: candidate) {
            candidate = folder.appendingPathComponent("\(name) \(number).app")
            number += 1
        }
        return candidate
    }
}
