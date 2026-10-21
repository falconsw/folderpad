import Foundation

/// Finds the apps Launchpad used to show: everything in the Applications folders.
nonisolated enum AppCatalog {
    static var searchRoots: [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    static func scan(roots: [URL] = searchRoots) -> [InstalledApp] {
        let keys: [URLResourceKey] = [.isPackageKey, .isSymbolicLinkKey]
        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                // Apps sit at most a couple of folders deep (Utilities, vendor folders).
                if enumerator.level >= 3 { enumerator.skipDescendants() }
                guard url.pathExtension.lowercased() == "app" else { continue }

                let values = try? url.resourceValues(forKeys: Set(keys))
                let bundle: URL
                if values?.isSymbolicLink == true {
                    // Safari lives in a cryptex behind /Applications/Safari.app.
                    bundle = url.resolvingSymlinksInPath()
                    guard (try? bundle.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true else { continue }
                } else if values?.isPackage == true {
                    bundle = url
                } else {
                    continue // Finder aliases, such as the ones inside groups.
                }

                guard seen.insert(bundle.pathKey).inserted else { continue }
                apps.append(InstalledApp(bundleURL: bundle))
            }
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

extension InstalledApp {
    nonisolated init(bundleURL url: URL) {
        let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) as? [String: Any]
        var name = FileManager.default.displayName(atPath: url.path)
        if name.lowercased().hasSuffix(".app") { name.removeLast(4) }
        self.init(
            url: url,
            name: name,
            bundleID: info?["CFBundleIdentifier"] as? String,
            category: info?["LSApplicationCategoryType"] as? String
        )
    }
}
