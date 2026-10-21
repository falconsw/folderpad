import SwiftUI

enum SidebarItem: Hashable {
    case allApps
    case group(String)
    case dockItem(String)
}

struct ContentView: View {
    @Environment(Library.self) private var library
    @State private var selection: SidebarItem? = .allApps
    @State private var renameDraft = ""

    var body: some View {
        @Bindable var library = library
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        } detail: {
            detail
        }
        .sheet(item: $library.sheet) { sheet in
            switch sheet {
            case .newGroup:
                NewGroupSheet { selection = .group($0) }
            case .suggestions:
                SuggestionsSheet()
            }
        }
        .alert("Rename Group", isPresented: isPresent(\.groupToRename), presenting: library.groupToRename) { group in
            TextField("Name", text: $renameDraft)
            Button("Rename") {
                if let id = library.rename(group, to: renameDraft) { selection = .group(id) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            Text("Delete “\(library.groupToDelete?.name ?? "")”?"),
            isPresented: isPresent(\.groupToDelete),
            titleVisibility: .visible,
            presenting: library.groupToDelete
        ) { group in
            Button("Delete Group", role: .destructive) { library.delete(group) }
        } message: { _ in
            Text("The folder goes to the Trash and leaves the Dock. Your apps stay where they are.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
            Button("OK") {}
        } message: {
            Text(library.error ?? "")
        }
        .onChange(of: library.groupToRename) { _, group in
            renameDraft = group?.name ?? ""
        }
        .onChange(of: library.groups) { _, groups in
            if case .group(let id) = selection, !groups.contains(where: { $0.id == id }) { selection = .allApps }
        }
        .onChange(of: library.dockItems) { _, items in
            if case .dockItem(let id) = selection, !items.contains(where: { $0.id == id }) { selection = .allApps }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Finder or the Dock may have changed things while Folderpad was in the background.
            library.reload()
            library.rescanIfStale()
        }
        .onAppear(perform: selectRequestedGroup)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .group(let id):
            if let group = library.group(withID: id) {
                GroupDetailView(group: group).id(group.id)
            }
        case .dockItem(let id):
            if let item = library.dockItems.first(where: { $0.id == id }) {
                DockItemView(item: item) { selection = .group($0) }.id(item.id)
            }
        case .allApps, nil:
            AllAppsView()
        }
    }

    private func isPresent(_ keyPath: ReferenceWritableKeyPath<Library, AppGroup?>) -> Binding<Bool> {
        Binding(
            get: { library[keyPath: keyPath] != nil },
            set: { if !$0 { library[keyPath: keyPath] = nil } }
        )
    }

    /// Debug builds: `FOLDERPAD_SELECT=<group name>` opens that group and
    /// `FOLDERPAD_SHEET=suggestions` the suggestions, for screenshots.
    private func selectRequestedGroup() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let name = environment["FOLDERPAD_SELECT"], let group = library.groups.first(where: { $0.name == name }) {
            selection = .group(group.id)
        }
        if environment["FOLDERPAD_SHEET"] == "suggestions" { library.sheet = .suggestions }
        #endif
    }
}
