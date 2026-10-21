import SwiftUI

struct SettingsView: View {
    @Environment(Library.self) private var library
    @AppStorage(Pref.newGroupDisplay) private var display = DockDisplay.folder.rawValue
    @AppStorage(Pref.newGroupContent) private var content = DockContent.grid.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Groups folder", selection: Binding(get: { library.location }, set: { library.setLocation($0) })) {
                    ForEach(GroupsLocation.allCases) { location in
                        Text(location.title).tag(location)
                    }
                }
                LabeledContent("Path") {
                    Text((library.location.url.path as NSString).abbreviatingWithTildeInPath)
                        .textSelection(.enabled)
                }
                if !library.location.isWritable {
                    Label("This account can't write to that folder. Choose the one in your home folder.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("Groups are ordinary folders of aliases. Finder and the Dock show them without Folderpad running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Folders Folderpad Adds to the Dock") {
                Picker("Display as", selection: $display) {
                    Text("Folder (Launchpad-style icon)").tag(DockDisplay.folder.rawValue)
                    Text("Stack").tag(DockDisplay.stack.rawValue)
                }
                Picker("Opens as", selection: $content) {
                    Text("Grid").tag(DockContent.grid.rawValue)
                    Text("Fan").tag(DockContent.fan.rawValue)
                    Text("List").tag(DockContent.list.rawValue)
                    Text("Automatic").tag(DockContent.automatic.rawValue)
                }
            }

        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}
