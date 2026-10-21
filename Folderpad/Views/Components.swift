import SwiftUI

/// An app as Launchpad showed it: icon above, name below.
struct AppTile: View {
    let icon: NSImage
    let name: String
    var caption: String?
    var isDimmed = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 64, height: 64)
            Text(name)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 104)
        .padding(.vertical, 8)
        .opacity(isDimmed ? 0.5 : 1)
        .contentShape(.rect(cornerRadius: 12))
    }
}

/// Group actions, shared by the sidebar's context menu and the group's toolbar.
struct GroupMenu: View {
    @Environment(Library.self) private var library
    let group: AppGroup

    var body: some View {
        if library.dockStyles[group.id] == nil {
            Button("Show in the Dock") { library.setInDock(group, true) }
        } else {
            Button("Remove from the Dock") { library.setInDock(group, false) }
        }
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([group.folder])
        }
        Divider()
        Button("Rename…") { library.groupToRename = group }
        Button("Delete Group…", role: .destructive) { library.groupToDelete = group }
    }
}

/// "Add to Group" submenu for apps chosen in All Apps.
struct AddToGroupMenu: View {
    @Environment(Library.self) private var library
    let apps: [URL]

    var body: some View {
        Menu("Add to Group") {
            ForEach(library.groups) { group in
                Button(group.name) { library.add(apps, to: group) }
            }
            if !library.groups.isEmpty { Divider() }
            Button("New Group…") {
                library.pendingApps = apps
                library.sheet = .newGroup
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    let prompt: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 8))
    }
}

func openApp(_ url: URL) {
    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
}
