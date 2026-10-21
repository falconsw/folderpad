import AppKit

/// App and group icons, cached so scrolling a grid of a few hundred apps stays smooth.
enum Icons {
    private static let cache = NSCache<NSString, NSImage>()

    static func app(_ url: URL) -> NSImage {
        cached("app:" + url.path) { NSWorkspace.shared.icon(forFile: url.path) }
    }

    /// The group's Launchpad-style icon, as it is or will be set on the folder.
    static func group(_ group: AppGroup) -> NSImage {
        let targets = group.items.compactMap(\.target)
        return cached("group:" + targets.map(\.path).joined(separator: "|")) { FolderIcon.image(for: targets) }
    }

    static let missingApp: NSImage = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()

    private static func cached(_ key: String, make: () -> NSImage) -> NSImage {
        if let image = cache.object(forKey: key as NSString) { return image }
        let image = make()
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}
