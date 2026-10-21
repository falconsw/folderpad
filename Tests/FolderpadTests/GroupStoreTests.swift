import Foundation
import Testing
@testable import Folderpad

/// Runs against a throwaway folder, never the real Applications folder.
struct GroupStoreTests {
    let root: URL
    let store: GroupStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("folderpad-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = GroupStore(root: root)
    }

    /// A minimal app bundle, enough for Finder and bookmarks to treat it as an app.
    private func makeApp(_ name: String, in folder: URL? = nil) throws -> URL {
        let app = (folder ?? root.appendingPathComponent("Apps", isDirectory: true)).appendingPathComponent("\(name).app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: NSDictionary = ["CFBundleIdentifier": "test.\(name)", "CFBundlePackageType": "APPL", "CFBundleName": name]
        try info.write(to: contents.appendingPathComponent("Info.plist"))
        return app
    }

    @Test func newGroupIsFoundWhileEmpty() throws {
        try store.createGroup(named: "IDE")
        #expect(store.groups().map(\.name) == ["IDE"])
        #expect(store.groups().first?.items.isEmpty == true)
    }

    @Test func addingAnAppWritesAFinderAliasOnce() throws {
        let folder = try store.createGroup(named: "Tools")
        let app = try makeApp("Sample")

        let alias = try #require(try store.add(app, to: folder))
        let values = try alias.resourceValues(forKeys: [.isAliasFileKey, .isPackageKey])
        #expect(values.isAliasFile == true)
        #expect(values.isPackage == false)
        #expect(alias.lastPathComponent == "Sample.app")
        #expect(store.items(in: folder).map(\.target?.pathKey) == [app.pathKey])

        #expect(try store.add(app, to: folder) == nil)
        #expect(store.items(in: folder).count == 1)
    }

    @Test func handMadeAliasFoldersAreGroups() throws {
        // Like a folder built in Finder with "Make Alias": no marker, only aliases.
        let folder = root.appendingPathComponent("DEV", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let app = try makeApp("Xcode")
        let bookmark = try app.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(bookmark, to: folder.appendingPathComponent("Xcode.app"))

        #expect(store.isGroupFolder(folder))
        #expect(store.groups().first?.items.first?.name == "Xcode")
    }

    @Test func foldersWithRealAppsAreNotGroups() throws {
        // Like /Applications/Utilities or a vendor folder.
        let utilities = root.appendingPathComponent("Utilities", isDirectory: true)
        _ = try makeApp("Terminal", in: utilities)
        #expect(!store.isGroupFolder(utilities))
        #expect(!store.isGroupFolder(root.appendingPathComponent("Apps")))
    }

    @Test func removingDeletesOnlyTheAlias() throws {
        let folder = try store.createGroup(named: "AI")
        let app = try makeApp("Claude")
        try store.add(app, to: folder)

        try store.remove(try #require(store.items(in: folder).first))
        #expect(store.items(in: folder).isEmpty)
        #expect(FileManager.default.fileExists(atPath: app.path))
        // The marker keeps the emptied folder a group.
        #expect(store.groups().map(\.name) == ["AI"])
    }

    @Test func deletedAppsShowAsMissing() throws {
        let folder = try store.createGroup(named: "Old")
        let app = try makeApp("Gone")
        try store.add(app, to: folder)
        try FileManager.default.removeItem(at: app)

        let item = try #require(store.items(in: folder).first)
        #expect(item.isMissing)
        #expect(item.name == "Gone")
    }

    @Test func renameKeepsTheAliases() throws {
        let folder = try store.createGroup(named: "ide")
        try store.add(try makeApp("Cursor"), to: folder)

        let renamed = try store.rename(folder, to: "IDE")
        #expect(renamed.lastPathComponent == "IDE")
        #expect(store.items(in: renamed).map(\.name) == ["Cursor"])

        try store.createGroup(named: "DEV")
        #expect(throws: GroupStore.Failure.self) { try store.rename(renamed, to: "DEV") }
    }

    @Test func trashRefusesFoldersWithMoreThanAliases() throws {
        let folder = try store.createGroup(named: "Mixed")
        try Data("notes".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        #expect(throws: GroupStore.Failure.self) { try store.trash(folder) }
        #expect(FileManager.default.fileExists(atPath: folder.path))
    }

    @Test func namesAreValidated() throws {
        for bad in ["", "   ", ".hidden", "a/b", "a:b", "Thing.app"] {
            #expect(throws: GroupStore.Failure.self) { try GroupStore.validated(bad) }
        }
        #expect(try GroupStore.validated("  Design  ") == "Design")
        try store.createGroup(named: "Games")
        #expect(throws: GroupStore.Failure.self) { try store.createGroup(named: "games") }
    }

    @Test func catalogFindsHiddenAppSymlinks() throws {
        // Like /Applications/Safari.app: a symlink into a cryptex, flagged hidden.
        let real = try makeApp("Browser", in: root.appendingPathComponent(".cryptex", isDirectory: true))
        let link = root.appendingPathComponent("Browser.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        #expect(link.withUnsafeFileSystemRepresentation { lchflags($0!, UInt32(UF_HIDDEN)) } == 0)

        let apps = AppCatalog.scan(roots: [root])
        #expect(apps.map(\.name) == ["Browser"])
    }

    @Test func catalogFindsAppsButNotAliases() throws {
        let folder = try store.createGroup(named: "Group")
        let app = try makeApp("Finder Test")
        try store.add(app, to: folder)

        let apps = AppCatalog.scan(roots: [root])
        #expect(apps.map(\.id) == [app.pathKey])
        #expect(apps.first?.bundleID == "test.Finder Test")
    }
}
