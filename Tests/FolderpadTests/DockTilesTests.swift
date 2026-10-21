import Foundation
import Testing
@testable import Folderpad

/// Works on arrays shaped like the Dock's `persistent-others`, never the real Dock.
struct DockTilesTests {
    private func folderTile(_ urlString: String, label: String, display: Int = 0, extra: [String: Any] = [:]) -> DockTiles.Tile {
        var data: [String: Any] = [
            "file-data": ["_CFURLString": urlString, "_CFURLStringType": 15],
            "file-label": label, "file-type": 2, "displayas": display, "showas": 0, "arrangement": 1,
        ]
        data.merge(extra) { $1 }
        return ["tile-type": "directory-tile", "tile-data": data]
    }

    private let downloads: DockTiles.Tile = [
        "tile-type": "directory-tile",
        "tile-data": [
            "file-data": ["_CFURLString": "file:///Users/someone/Downloads/", "_CFURLStringType": 15],
            "file-label": "Downloads", "file-type": 2, "displayas": 1, "showas": 1, "arrangement": 2,
        ] as [String: Any],
    ]

    private let link: DockTiles.Tile = [
        "tile-type": "url-tile",
        "tile-data": ["label": "Docs", "url": ["_CFURLString": "https://example.com", "_CFURLStringType": 15]] as [String: Any],
    ]

    @Test func findsFoldersWithSpacesInTheirName() {
        let tiles = [downloads, folderTile("file:///Applications/My%20Group/", label: "My Group")]
        #expect(DockTiles.index(of: URL(fileURLWithPath: "/Applications/My Group"), in: tiles) == 1)
        #expect(DockTiles.index(of: URL(fileURLWithPath: "/Applications/Other"), in: tiles) == nil)
    }

    @Test func addsANewFolderAfterTheOthers() throws {
        let style = DockStyle(display: .folder, content: .grid, sort: .name)
        let tiles = DockTiles.setting(URL(fileURLWithPath: "/Applications/IDE"), style: style, in: [downloads])

        #expect(tiles.count == 2)
        let data = try #require(tiles[1]["tile-data"] as? [String: Any])
        #expect(tiles[1]["tile-type"] as? String == "directory-tile")
        #expect((data["file-data"] as? [String: Any])?["_CFURLString"] as? String == "file:///Applications/IDE/")
        #expect(data["file-label"] as? String == "IDE")
        #expect(DockTiles.style(of: tiles[1]) == style)
    }

    @Test func restylesInPlaceAndKeepsTheDocksOwnKeys() throws {
        let tile = folderTile("file:///Applications/IDE/", label: "IDE", extra: ["GUID": 42, "book": Data([1, 2, 3])])
        let style = DockStyle(display: .folder, content: .list, sort: .kind)
        let tiles = DockTiles.setting(URL(fileURLWithPath: "/Applications/IDE"), style: style, in: [tile, downloads])

        #expect(tiles.count == 2)
        #expect(DockTiles.style(of: tiles[0]) == style)
        let data = try #require(tiles[0]["tile-data"] as? [String: Any])
        #expect(data["GUID"] as? Int == 42)
        #expect(data["book"] as? Data == Data([1, 2, 3]))
    }

    @Test func renamePointsTheTileAtTheNewFolder() throws {
        let tile = folderTile("file:///Applications/ide/", label: "ide", extra: ["book": Data([1])])
        let tiles = DockTiles.moving(URL(fileURLWithPath: "/Applications/ide"), to: URL(fileURLWithPath: "/Applications/Code"), in: [tile])

        let data = try #require(tiles[0]["tile-data"] as? [String: Any])
        #expect(data["file-label"] as? String == "Code")
        #expect(data["book"] == nil)
        #expect(DockTiles.path(of: tiles[0]) == "/Applications/Code")
    }

    @Test func listsEveryTileIncludingGroupsFilesAndLinks() {
        let file: DockTiles.Tile = [
            "tile-type": "file-tile",
            "tile-data": ["file-data": ["_CFURLString": "file:///Users/someone/notes.txt", "_CFURLStringType": 15], "file-label": "notes"] as [String: Any],
        ]
        let items = DockTiles.items(in: [folderTile("file:///Applications/IDE/", label: "IDE"), downloads, file, link])

        #expect(items.map(\.label) == ["IDE", "Downloads", "notes", "Docs"])
        #expect(items.map(\.kind) == [.folder, .folder, .file, .link])
        #expect(items[0].id == "/Applications/IDE")
        #expect(items[1].style == DockStyle(display: .folder, content: .fan, sort: .dateAdded))
        #expect(items[3].url?.absoluteString == "https://example.com")
    }

    @Test func removesAnyTileByID() {
        let ide = folderTile("file:///Applications/IDE/", label: "IDE")
        let tiles = [ide, downloads, link]

        #expect(DockTiles.items(in: DockTiles.removing(id: "/Applications/IDE", from: tiles)).map(\.label) == ["Downloads", "Docs"])
        #expect(DockTiles.items(in: DockTiles.removing(id: "label:Docs", from: tiles)).map(\.label) == ["IDE", "Downloads"])
        #expect(DockTiles.removing(URL(fileURLWithPath: "/Applications/IDE"), from: tiles).count == 2)
    }

    @Test func reordersByIDAndKeepsUnnamedTilesAtTheEnd() {
        let ide = folderTile("file:///Applications/IDE/", label: "IDE")
        let dev = folderTile("file:///Applications/DEV/", label: "DEV")
        let tiles = [ide, dev, downloads, link]

        let reordered = DockTiles.reordered(tiles, ids: ["/Users/someone/Downloads", "/Applications/IDE"])
        #expect(DockTiles.items(in: reordered).map(\.label) == ["Downloads", "IDE", "DEV", "Docs"])
    }
}
