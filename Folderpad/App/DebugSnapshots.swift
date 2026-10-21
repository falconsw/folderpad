#if DEBUG
import AppKit

/// Debug builds only: `open --env FOLDERPAD_SNAPSHOT_DIR=/some/dir -a Folderpad.app` writes a PNG
/// of every visible window there every two seconds, for checking layouts without screen recording.
enum DebugSnapshots {
    private static var timer: Timer?

    static func startIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["FOLDERPAD_SNAPSHOT_DIR"] else { return }
        if let appearance = ProcessInfo.processInfo.environment["FOLDERPAD_APPEARANCE"] {
            NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated { capture(into: directory) }
        }
    }

    private typealias WindowImageFunction = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    /// The window server image includes glass and materials, which cacheDisplay does not draw.
    /// The function is hidden from the current SDK, so it is looked up at runtime.
    private static let windowImage: WindowImageFunction? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(symbol, to: WindowImageFunction.self)
    }()

    private static func capture(into directory: URL) {
        for (index, window) in NSApp.windows.enumerated() where window.isVisible {
            let name = window.title.isEmpty ? "window-\(index)" : window.title
            let file = directory.appendingPathComponent("\(name.replacingOccurrences(of: "/", with: "-")).png")
            // kCGWindowListOptionIncludingWindow, kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution
            if let windowImage, let image = windowImage(.null, 1 << 3, UInt32(window.windowNumber), 1 | 8)?.takeRetainedValue() {
                try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: file)
                continue
            }
            guard let view = window.contentView?.superview ?? window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: file)
        }
    }
}
#endif
