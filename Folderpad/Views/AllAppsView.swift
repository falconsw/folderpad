import SwiftUI

struct AllAppsView: View {
    @Environment(Library.self) private var library
    @State private var search = ""
    @State private var onlyUngrouped = false

    var body: some View {
        let memberships = library.memberships
        let apps = library.apps.filter { app in
            (search.isEmpty || app.name.localizedCaseInsensitiveContains(search))
                && (!onlyUngrouped || memberships[app.id] == nil)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if library.groups.isEmpty {
                    WelcomeBanner()
                }
                if apps.isEmpty && !library.isScanning {
                    if search.isEmpty {
                        ContentUnavailableView("Every app is in a group", systemImage: "checkmark.circle")
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12, alignment: .top)], spacing: 16) {
                    ForEach(apps) { app in
                        AppTile(icon: Icons.app(app.url), name: app.name, caption: memberships[app.id]?.joined(separator: ", "))
                            .draggable(app.url)
                            .onTapGesture(count: 2) { openApp(app.url) }
                            .contextMenu {
                                AddToGroupMenu(apps: [app.url])
                                Divider()
                                Button("Open") { openApp(app.url) }
                                Button("Show in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([app.url])
                                }
                            }
                    }
                }
            }
            .padding(28)
        }
        .overlay {
            if library.isScanning && library.apps.isEmpty { ProgressView() }
        }
        .navigationTitle("All Apps")
        .navigationSubtitle("Drag an app onto a group in the sidebar")
        .searchable(text: $search, placement: .toolbar, prompt: "Search Apps")
        .toolbar {
            Toggle(isOn: $onlyUngrouped) {
                Label("Not in a Group", systemImage: "line.3.horizontal.decrease")
            }
            .help("Show only apps that are not in a group")
        }
    }
}

private struct WelcomeBanner: View {
    @Environment(Library.self) private var library

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 8) {
                Text("App folders, back in your Dock")
                    .font(.title3.weight(.semibold))
                Text("Launchpad is gone as of macOS 26. Gather your apps into groups and each one sits in the Dock as a folder, looking just like a Launchpad folder. Groups stay after you quit Folderpad.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Suggest Groups…") { library.sheet = .suggestions }
                        .buttonStyle(.borderedProminent)
                    Button("New Group…") { library.sheet = .newGroup }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
    }
}
