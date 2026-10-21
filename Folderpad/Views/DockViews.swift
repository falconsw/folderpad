import AppKit
import SwiftUI

/// Whether a folder is in the Dock, and how the Dock shows it. Used for groups and for any
/// other folder after the divider; every change is written to the Dock's preferences.
struct DockSettings: View {
    @Environment(Library.self) private var library
    let folder: URL
    /// Nil when the folder is not in the Dock.
    let style: DockStyle?
    let caption: LocalizedStringKey
    let onToggle: (Bool) -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: Binding(get: { style != nil }, set: { onToggle($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show in the Dock")
                            .font(.headline)
                        Text(caption)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if style != nil {
                    Divider()
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                        GridRow {
                            Text("Display as")
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            Picker("Display as", selection: binding(\.display)) {
                                Text("Folder").tag(DockDisplay.folder)
                                Text("Stack").tag(DockDisplay.stack)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                        }
                        GridRow {
                            Text("Opens as")
                                .foregroundStyle(.secondary)
                            Picker("Opens as", selection: binding(\.content)) {
                                Text("Grid").tag(DockContent.grid)
                                Text("Fan").tag(DockContent.fan)
                                Text("List").tag(DockContent.list)
                                Text("Automatic").tag(DockContent.automatic)
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                        GridRow {
                            Text("Sort by")
                                .foregroundStyle(.secondary)
                            Picker("Sort by", selection: binding(\.sort)) {
                                Text("Name").tag(DockSort.name)
                                Text("Kind").tag(DockSort.kind)
                                Text("Date Added").tag(DockSort.dateAdded)
                                Text("Date Modified").tag(DockSort.dateModified)
                                Text("Date Created").tag(DockSort.dateCreated)
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                    Text(style?.display == .folder
                         ? "Folder shows the folder's own icon; for a group that is its Launchpad-style icon. The Dock restarts for a moment to apply changes."
                         : "Stack shows the icons inside, piled up. The Dock restarts for a moment to apply changes.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<DockStyle, Value>) -> Binding<Value> {
        Binding(
            get: { (style ?? DockStyle())[keyPath: keyPath] },
            set: { value in
                var changed = style ?? DockStyle()
                changed[keyPath: keyPath] = value
                library.setDockStyle(changed, for: folder)
            }
        )
    }
}

/// One tile after the Dock's divider, whatever it is.
struct DockItemView: View {
    @Environment(Library.self) private var library
    let item: DockItem
    /// Opens the group when the tile is one.
    let onOpenGroup: (String) -> Void

    var body: some View {
        let group = library.group(withID: item.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 18) {
                    DockItemIcon(item: item)
                        .frame(width: 92, height: 92)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label)
                            .font(.largeTitle.weight(.semibold))
                        Text(kindDescription(isGroup: group != nil))
                            .foregroundStyle(.secondary)
                        if let url = item.url {
                            Text(url.isFileURL ? (url.path as NSString).abbreviatingWithTildeInPath : url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }

                if item.kind == .folder, let url = item.url {
                    DockSettings(
                        folder: url,
                        style: item.style,
                        caption: "Turning this off takes the folder out of the Dock. The folder itself stays where it is."
                    ) { inDock in
                        if !inDock { library.removeFromDock(item) }
                    }
                }

                HStack {
                    if let group {
                        Button("Edit Group") { onOpenGroup(group.id) }
                            .buttonStyle(.borderedProminent)
                    }
                    if let url = item.url, url.isFileURL {
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                    Button("Remove from the Dock", role: .destructive) { library.removeFromDock(item) }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(item.label)
    }

    private func kindDescription(isGroup: Bool) -> LocalizedStringKey {
        if isGroup { return "Folderpad group in the Dock" }
        switch item.kind {
        case .folder: return "Folder in the Dock"
        case .file: return "File in the Dock"
        case .link: return "Web link in the Dock"
        }
    }
}

/// The icon the Dock would show: a group's Launchpad-style icon, else Finder's icon.
struct DockItemIcon: View {
    @Environment(Library.self) private var library
    let item: DockItem

    var body: some View {
        if let group = library.group(withID: item.id) {
            Image(nsImage: Icons.group(group)).resizable()
        } else if let url = item.url, url.isFileURL {
            Image(nsImage: Icons.app(url)).resizable()
        } else {
            Image(systemName: "link")
                .resizable()
                .scaledToFit()
                .padding(6)
                .foregroundStyle(.secondary)
        }
    }
}

/// Lets the person pick folders to pin after the Dock's divider.
@MainActor
func chooseFoldersToPin(into library: Library) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = true
    panel.prompt = "Pin to Dock"
    panel.message = "Choose folders to keep in the Dock."
    if panel.runModal() == .OK {
        library.pinToDock(panel.urls)
    }
}
