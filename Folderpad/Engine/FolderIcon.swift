import AppKit

/// A Launchpad-style folder icon: a frosted tile with the group's first apps in a grid.
/// Set on the group folder, it is what Finder shows, and what the Dock shows when the
/// group is displayed as a folder.
enum FolderIcon {
    static func image(for apps: [URL], size: CGFloat = 512) -> NSImage {
        let icons = apps.prefix(9).map { NSWorkspace.shared.icon(forFile: $0.path) }
        return NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            draw(icons, in: rect)
            return true
        }
    }

    static func apply(to folder: URL, apps: [URL]) {
        NSWorkspace.shared.setIcon(image(for: apps), forFile: folder.path, options: .excludeQuickDrawElementsIconCreationOption)
    }

    /// Lays out a 1024-unit design in `rect`, flipped (y grows downward).
    private static func draw(_ icons: [NSImage], in rect: NSRect) {
        let unit = rect.width / 1024
        func frame(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
            NSRect(x: rect.minX + x * unit, y: rect.minY + y * unit, width: width * unit, height: height * unit)
        }

        // The tile uses the standard macOS icon margins (824 on a 1024 canvas).
        let tile = frame(100, 100, 824, 824)
        let shape = NSBezierPath(roundedRect: tile, xRadius: 186 * unit, yRadius: 186 * unit)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = 28 * unit
        shadow.shadowOffset = NSSize(width: 0, height: -12 * unit)
        shadow.set()
        NSColor(white: 0.9, alpha: 0.96).setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Frosted glass: light at the top, a cool grey at the bottom.
        NSGradient(colors: [
            NSColor(srgbRed: 0.99, green: 0.99, blue: 1.0, alpha: 0.97),
            NSColor(srgbRed: 0.83, green: 0.85, blue: 0.89, alpha: 0.97),
        ])?.draw(in: shape, angle: 90)

        let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 3 * unit, dy: 3 * unit), xRadius: 183 * unit, yRadius: 183 * unit)
        rim.lineWidth = 6 * unit
        NSColor.white.withAlphaComponent(0.75).setStroke()
        rim.stroke()

        // Up to four apps get a 2×2 grid so they stay legible at Dock size; more get 3×3.
        let columns = icons.count <= 4 ? 2 : 3
        let inset: CGFloat = columns == 2 ? 118 : 86
        let cell = (824 - inset * 2) / CGFloat(columns)
        for (index, icon) in icons.enumerated() {
            let column = CGFloat(index % columns)
            let row = CGFloat(index / columns)
            let target = frame(100 + inset + column * cell, 100 + inset + row * cell, cell, cell)
            icon.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
        }
    }
}
