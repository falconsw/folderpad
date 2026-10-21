import Foundation

/// An app bundle found on disk.
nonisolated struct InstalledApp: Identifiable, Hashable, Sendable {
    let url: URL
    /// Finder's name for the app, localized and without `.app`.
    let name: String
    let bundleID: String?
    /// `LSApplicationCategoryType`, the category the developer picked for the App Store.
    let category: String?

    var id: String { url.pathKey }
    /// Ships with macOS (Safari, Notes, Utilities…), as opposed to installed by the user.
    var isSystem: Bool { id.hasPrefix("/System/") }
}

/// One Finder alias inside a group folder.
nonisolated struct GroupItem: Identifiable, Hashable, Sendable {
    let aliasURL: URL
    /// The app the alias points to, or nil when the app is gone.
    let target: URL?
    /// The alias's own name, which is what the Dock shows.
    let name: String

    var id: String { aliasURL.pathKey }
    var isMissing: Bool { target == nil }
}

/// A folder of app aliases: what a Launchpad folder used to be.
nonisolated struct AppGroup: Identifiable, Hashable, Sendable {
    let folder: URL
    var items: [GroupItem]

    var id: String { folder.pathKey }
    var name: String { folder.lastPathComponent }
}

extension URL {
    /// One spelling per file for comparisons: symlinks resolved, no trailing slash.
    nonisolated var pathKey: String {
        var path = resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
