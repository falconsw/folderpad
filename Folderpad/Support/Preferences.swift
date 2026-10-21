import Foundation

/// UserDefaults keys shared by `@AppStorage` views and non-view code.
enum Pref {
    static let location = "groupsLocation"
    static let newGroupInDock = "newGroupInDock"
    static let newGroupDisplay = "newGroupDockDisplay"
    static let newGroupContent = "newGroupDockContent"

    /// How a group looks in the Dock when Folderpad adds it.
    static var newGroupStyle: DockStyle {
        let defaults = UserDefaults.standard
        var style = DockStyle()
        if let display = defaults.object(forKey: newGroupDisplay) as? Int, let value = DockDisplay(rawValue: display) {
            style.display = value
        }
        if let content = defaults.object(forKey: newGroupContent) as? Int, let value = DockContent(rawValue: content) {
            style.content = value
        }
        return style
    }
}

/// Where group folders live. Finder and the Dock see them wherever they are: the
/// Applications folder keeps them next to the apps, the one in the home folder works
/// for accounts that are not administrators.
enum GroupsLocation: String, CaseIterable, Identifiable {
    case applications
    case home

    var id: String { rawValue }

    var url: URL {
        switch self {
        case .applications:
            URL(fileURLWithPath: "/Applications", isDirectory: true)
        case .home:
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        }
    }

    var title: String {
        switch self {
        case .applications: "Applications"
        case .home: "Applications in your home folder"
        }
    }

    var isWritable: Bool {
        switch self {
        case .applications: FileManager.default.isWritableFile(atPath: url.path)
        case .home: true
        }
    }

    /// The saved choice, otherwise the Applications folder when this account may write to it.
    static var current: GroupsLocation {
        if let saved = UserDefaults.standard.string(forKey: Pref.location), let location = GroupsLocation(rawValue: saved) {
            return location
        }
        return GroupsLocation.applications.isWritable ? .applications : .home
    }
}
