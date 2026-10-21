import Foundation

/// The Dock's own options for a folder tile, as the Dock's context menu offers them.
nonisolated enum DockDisplay: Int, CaseIterable, Sendable {
    case stack = 0
    case folder = 1
}

nonisolated enum DockContent: Int, CaseIterable, Sendable {
    case automatic = 0
    case fan = 1
    case grid = 2
    case list = 3
}

nonisolated enum DockSort: Int, CaseIterable, Sendable {
    case name = 1
    case dateAdded = 2
    case dateModified = 3
    case dateCreated = 4
    case kind = 5
}

nonisolated struct DockStyle: Hashable, Sendable {
    /// Folder shows the group's own icon, which looks like a Launchpad folder.
    var display: DockDisplay = .folder
    /// Grid is the closest to opening a Launchpad folder.
    var content: DockContent = .grid
    var sort: DockSort = .name
}

/// One tile after the Dock's divider: a folder, a file or a web link.
nonisolated struct DockItem: Identifiable, Hashable, Sendable {
    enum Kind: Sendable {
        case folder, file, link
    }

    /// The file's path, or the label for a tile without a file.
    let id: String
    let url: URL?
    let label: String
    let kind: Kind
    let style: DockStyle
}

/// Edits of the Dock's `persistent-others` array: the folders and files after the divider.
/// Pure functions, so they can be tested without touching the real Dock.
nonisolated enum DockTiles {
    typealias Tile = [String: Any]

    static func path(of tile: Tile) -> String? {
        guard let data = tile["tile-data"] as? [String: Any],
              let fileData = data["file-data"] as? [String: Any],
              let string = fileData["_CFURLString"] as? String else { return nil }
        // Type 15 is a URL string; type 0 a plain POSIX path.
        let url = (fileData["_CFURLStringType"] as? Int) == 0 ? URL(fileURLWithPath: string) : URL(string: string)
        return url?.pathKey
    }

    /// Every tile, in Dock order. Nothing is left out: groups, Downloads, files and links.
    static func items(in tiles: [Tile]) -> [DockItem] {
        tiles.map(item)
    }

    static func item(_ tile: Tile) -> DockItem {
        let data = tile["tile-data"] as? [String: Any] ?? [:]
        let type = tile["tile-type"] as? String
        let label = data["file-label"] as? String ?? data["label"] as? String ?? ""
        guard let path = path(of: tile) else {
            let link = (data["url"] as? [String: Any])?["_CFURLString"] as? String
            return DockItem(id: "label:" + label, url: link.flatMap(URL.init(string:)), label: label, kind: .link, style: style(of: tile))
        }
        let url = URL(fileURLWithPath: path)
        return DockItem(
            id: path, url: url, label: label.isEmpty ? url.lastPathComponent : label,
            kind: type == "directory-tile" ? .folder : .file, style: style(of: tile)
        )
    }

    static func removing(id: String, from tiles: [Tile]) -> [Tile] {
        tiles.filter { item($0).id != id }
    }

    /// Puts the tiles in the order of `ids`. Tiles not named keep their place at the end.
    static func reordered(_ tiles: [Tile], ids: [String]) -> [Tile] {
        let rank = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return tiles.enumerated()
            .sorted { lhs, rhs in
                let left = rank[item(lhs.element).id] ?? ids.count + lhs.offset
                let right = rank[item(rhs.element).id] ?? ids.count + rhs.offset
                return left < right
            }
            .map(\.element)
    }

    static func index(of folder: URL, in tiles: [Tile]) -> Int? {
        let key = folder.pathKey
        return tiles.firstIndex { path(of: $0) == key }
    }

    static func style(of tile: Tile) -> DockStyle {
        let data = tile["tile-data"] as? [String: Any] ?? [:]
        return DockStyle(
            display: DockDisplay(rawValue: data["displayas"] as? Int ?? 0) ?? .stack,
            content: DockContent(rawValue: data["showas"] as? Int ?? 0) ?? .automatic,
            sort: DockSort(rawValue: data["arrangement"] as? Int ?? 1) ?? .name
        )
    }

    static func makeTile(for folder: URL, style: DockStyle) -> Tile {
        [
            "tile-type": "directory-tile",
            "tile-data": [
                "file-data": fileData(for: folder),
                "file-label": folder.lastPathComponent,
                "file-type": 2,
                "displayas": style.display.rawValue,
                "showas": style.content.rawValue,
                "arrangement": style.sort.rawValue,
                "preferreditemsize": -1,
            ] as [String: Any],
        ]
    }

    /// Adds the folder after the existing tiles, or restyles its tile in place.
    static func setting(_ folder: URL, style: DockStyle, in tiles: [Tile]) -> [Tile] {
        var tiles = tiles
        guard let index = index(of: folder, in: tiles) else {
            tiles.append(makeTile(for: folder, style: style))
            return tiles
        }
        tiles[index] = editingData(of: tiles[index]) { data in
            data["displayas"] = style.display.rawValue
            data["showas"] = style.content.rawValue
            data["arrangement"] = style.sort.rawValue
        }
        return tiles
    }

    static func removing(_ folder: URL, from tiles: [Tile]) -> [Tile] {
        let key = folder.pathKey
        return tiles.filter { path(of: $0) != key }
    }

    /// Points the tile at a renamed folder. The stale bookmark goes; the Dock makes a new one.
    static func moving(_ old: URL, to new: URL, in tiles: [Tile]) -> [Tile] {
        guard let index = index(of: old, in: tiles) else { return tiles }
        var tiles = tiles
        tiles[index] = editingData(of: tiles[index]) { data in
            data["file-data"] = fileData(for: new)
            data["file-label"] = new.lastPathComponent
            data.removeValue(forKey: "book")
        }
        return tiles
    }

    private static func fileData(for folder: URL) -> [String: Any] {
        ["_CFURLString": URL(fileURLWithPath: folder.path, isDirectory: true).absoluteString, "_CFURLStringType": 15]
    }

    private static func editingData(of tile: Tile, _ edit: (inout [String: Any]) -> Void) -> Tile {
        var tile = tile
        var data = tile["tile-data"] as? [String: Any] ?? [:]
        edit(&data)
        tile["tile-data"] = data
        return tile
    }
}

/// The real Dock. It reads its preferences only when it starts, so every change ends in a restart.
enum Dock {
    private static let domain = "com.apple.dock" as CFString
    private static let key = "persistent-others" as CFString

    static func tiles() -> [DockTiles.Tile] {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key, domain) as? [DockTiles.Tile] ?? []
    }

    static func save(_ tiles: [DockTiles.Tile]) {
        CFPreferencesSetAppValue(key, tiles as CFArray, domain)
        CFPreferencesAppSynchronize(domain)
    }

    static func restart() {
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Dock"])
    }
}
