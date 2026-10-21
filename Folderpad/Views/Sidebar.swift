import SwiftUI

struct Sidebar: View {
    @Environment(Library.self) private var library
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label("All Apps", systemImage: "square.grid.3x3")
                .badge(library.apps.count)
                .tag(SidebarItem.allApps)

            Section("Groups") {
                ForEach(library.groups) { group in
                    GroupRow(group: group)
                        .tag(SidebarItem.group(group.id))
                }
            }

            Section {
                ForEach(library.dockItems) { item in
                    DockRow(item: item)
                        .tag(SidebarItem.dockItem(item.id))
                }
                .onMove { library.moveDockItems(from: $0, to: $1) }
            } header: {
                HStack {
                    Text("In the Dock")
                    Spacer()
                    Button { chooseFoldersToPin(into: library) } label: {
                        Image(systemName: "pin")
                    }
                    .buttonStyle(.borderless)
                    .help("Pin Folder to Dock…")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Button { library.sheet = .newGroup } label: {
                    Label("New Group", systemImage: "plus")
                }
                .help("New Group…")
                Spacer()
                Button { library.sheet = .suggestions } label: {
                    Label("Suggest", systemImage: "wand.and.sparkles")
                }
                .help("Suggest groups from app categories")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

private struct GroupRow: View {
    @Environment(Library.self) private var library
    let group: AppGroup
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: Icons.group(group))
                .resizable()
                .frame(width: 24, height: 24)
            Text(group.name)
                .lineLimit(1)
            Spacer(minLength: 4)
            if library.dockStyles[group.id] != nil {
                Image(systemName: "dock.rectangle")
                    .foregroundStyle(.secondary)
                    .help("Shown in the Dock")
            }
        }
        .badge(group.items.count)
        .padding(.vertical, 1)
        .background {
            if isTargeted {
                RoundedRectangle(cornerRadius: 6).strokeBorder(.tint, lineWidth: 2).padding(-4)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            library.add(urls, to: group)
            return true
        } isTargeted: {
            isTargeted = $0
        }
        .contextMenu {
            GroupMenu(group: group)
        }
    }
}

/// A tile after the Dock's divider. Drag to reorder it in the Dock.
private struct DockRow: View {
    @Environment(Library.self) private var library
    let item: DockItem

    var body: some View {
        HStack(spacing: 8) {
            DockItemIcon(item: item)
                .frame(width: 24, height: 24)
            Text(item.label)
                .lineLimit(1)
        }
        .padding(.vertical, 1)
        .contextMenu {
            if let url = item.url, url.isFileURL {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Divider()
            }
            Button("Remove from the Dock", role: .destructive) { library.removeFromDock(item) }
        }
    }
}
