import SwiftUI

struct GroupDetailView: View {
    @Environment(Library.self) private var library
    let group: AppGroup
    @State private var showingPicker = false
    @State private var isTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                DockSettings(
                    folder: group.folder,
                    style: library.dockStyles[group.id],
                    caption: "Appears after the divider, next to Downloads, and stays there after you quit Folderpad."
                ) { library.setInDock(group, $0) }
                if group.items.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12, alignment: .top)], spacing: 16) {
                        ForEach(group.items) { item in
                            GroupItemTile(item: item) { library.remove([item], from: group) }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.tint, lineWidth: 3)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            library.add(urls, to: group)
            return true
        } isTargeted: {
            isTargeted = $0
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItemGroup {
                Button { showingPicker = true } label: {
                    Label("Add Apps…", systemImage: "plus")
                }
                .help("Add Apps…")
                Menu {
                    GroupMenu(group: group)
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            AppPickerSheet(group: group)
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image(nsImage: Icons.group(group))
                .resizable()
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.largeTitle.weight(.semibold))
                Text("^[\(group.items.count) app](inflect: true)")
                    .foregroundStyle(.secondary)
                Text((group.folder.path as NSString).abbreviatingWithTildeInPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No apps yet", systemImage: "square.dashed")
        } description: {
            Text("Drag apps here from Finder or from All Apps, or pick them from a list.")
        } actions: {
            Button("Add Apps…") { showingPicker = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }
}

private struct GroupItemTile: View {
    let item: GroupItem
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        AppTile(
            icon: item.target.map(Icons.app) ?? Icons.missingApp,
            name: item.name,
            caption: item.isMissing ? "Missing" : nil,
            isDimmed: item.isMissing
        )
        .background {
            if isHovering { RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.6)) }
        }
        .overlay(alignment: .topLeading) {
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .gray)
                }
                .buttonStyle(.plain)
                .help("Remove from Group")
                .offset(x: 8, y: 2)
            }
        }
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { if let target = item.target { openApp(target) } }
        .contextMenu {
            Button("Open") { if let target = item.target { openApp(target) } }
                .disabled(item.isMissing)
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.target ?? item.aliasURL])
            }
            Divider()
            Button("Remove from Group", role: .destructive, action: onRemove)
        }
    }
}
