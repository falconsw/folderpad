import AppKit

/// App and group icons, cached so scrolling a grid of a few hundred apps stays smooth.
enum Icons {
    private static let cache = NSCache<NSString, NSImage>()

    static func app(_ url: URL) -> NSImage {
        cached("app:" + url.path) { NSWorkspace.shared.icon(forFile: url.path) }
    }

    /// The group's Launchpad-style icon, as it is or will be set on the folder.
    /// Cached per appearance so dark and light tiles do not clobber each other.
    static func group(_ group: AppGroup, dark: Bool = FolderIcon.systemIsDark) -> NSImage {
        let targets = group.items.compactMap(\.target)
        let key = "group:\(dark ? "d" : "l"):" + targets.map(\.path).joined(separator: "|")
        return cached(key) { FolderIcon.image(for: targets, dark: dark) }
    }

    static let missingApp: NSImage = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()

    /// Drops cached images, e.g. after a light/dark switch so group icons are redrawn.
    static func clear() { cache.removeAllObjects() }

    private static func cached(_ key: String, make: () -> NSImage) -> NSImage {
        if let image = cache.object(forKey: key as NSString) { return image }
        let image = make()
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}
