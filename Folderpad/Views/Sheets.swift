import SwiftUI

struct NewGroupSheet: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Pref.newGroupInDock) private var inDock = true
    @State private var name = ""
    /// Receives the new group's id.
    let onCreate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Group")
                .font(.title2.weight(.semibold))
            TextField("Name", text: $name, prompt: Text("Design, Games, Work…"))
                .textFieldStyle(.roundedBorder)
                .onSubmit(create)
            Toggle("Show in the Dock", isOn: $inDock)
            if !library.pendingApps.isEmpty {
                HStack(spacing: -6) {
                    ForEach(library.pendingApps.prefix(8), id: \.self) { app in
                        Image(nsImage: Icons.app(app))
                            .resizable()
                            .frame(width: 28, height: 28)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onDisappear { library.pendingApps = [] }
    }

    private func create() {
        guard let group = library.createGroup(named: name, apps: library.pendingApps, inDock: inDock) else { return }
        onCreate(group.id)
        dismiss()
    }
}

struct AppPickerSheet: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    let group: AppGroup
    @State private var search = ""
    @State private var picked: Set<String> = []

    var body: some View {
        let existing = Set(group.items.compactMap { $0.target?.pathKey })
        let apps = library.apps.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add Apps to “\(group.name)”")
                    .font(.title2.weight(.semibold))
                SearchField(text: $search, prompt: "Search Apps")
            }
            .padding(20)

            List(apps) { app in
                let isAdded = existing.contains(app.id)
                Toggle(isOn: Binding(
                    get: { isAdded || picked.contains(app.id) },
                    set: { if $0 { picked.insert(app.id) } else { picked.remove(app.id) } }
                )) {
                    HStack(spacing: 10) {
                        Image(nsImage: Icons.app(app.url))
                            .resizable()
                            .frame(width: 26, height: 26)
                        Text(app.name)
                        Spacer()
                        if isAdded {
                            Text("Already in the group")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(isAdded)
            }
            .listStyle(.inset)

            Divider()
            HStack {
                Text("\(picked.count) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    library.add(library.apps.filter { picked.contains($0.id) }.map(\.url), to: group)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(picked.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 480, height: 580)
    }
}

/// Groups proposed from App Store categories, editable before anything is created.
struct SuggestionsSheet: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Pref.newGroupInDock) private var inDock = true
    @State private var includeSystem = false
    @State private var suggestions: [GroupSuggestion] = []
    @State private var skipped: Set<String> = []
    @State private var leftOut: Set<String> = []

    private var accepted: [GroupSuggestion] {
        suggestions.compactMap { suggestion in
            guard !skipped.contains(suggestion.id) else { return nil }
            var kept = suggestion
            kept.apps.removeAll { leftOut.contains($0.id) }
            kept.name = kept.name.trimmingCharacters(in: .whitespaces)
            return kept.apps.isEmpty || kept.name.isEmpty ? nil : kept
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggested Groups")
                    .font(.title2.weight(.semibold))
                Text("Based on the category each app has on the App Store. Rename a group, untick it, or click an app to leave it out.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            if suggestions.isEmpty {
                ContentUnavailableView(
                    "Nothing to suggest",
                    systemImage: "checkmark.circle",
                    description: Text("Apps with a category are already in groups, or no category has two apps.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($suggestions) { $suggestion in
                            SuggestionCard(
                                suggestion: $suggestion,
                                isOn: Binding(
                                    get: { !skipped.contains(suggestion.id) },
                                    set: { if $0 { skipped.remove(suggestion.id) } else { skipped.insert(suggestion.id) } }
                                ),
                                leftOut: $leftOut,
                                existing: library.groups.contains { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }
                            )
                        }
                    }
                    .padding(20)
                }
            }

            Divider()
            HStack(spacing: 16) {
                Toggle("Include Apple apps", isOn: $includeSystem)
                Toggle("Show in the Dock", isOn: $inDock)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Groups") {
                    library.apply(accepted, inDock: inDock)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(accepted.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 640, height: 620)
        // Also reruns when the app scan finishes after the sheet opened.
        .task(id: [includeSystem ? 1 : 0, library.apps.count]) {
            let memberships = library.memberships
            let loose = library.apps.filter { memberships[$0.id] == nil }
            suggestions = Suggestions.make(from: loose, includeSystem: includeSystem)
        }
    }
}

private struct SuggestionCard: View {
    @Binding var suggestion: GroupSuggestion
    @Binding var isOn: Bool
    @Binding var leftOut: Set<String>
    let existing: Bool

    var body: some View {
        let kept = suggestion.apps.filter { !leftOut.contains($0.id) }.count
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Toggle("Create", isOn: $isOn)
                        .labelsHidden()
                    Image(systemName: suggestion.symbol)
                        .foregroundStyle(.tint)
                        .frame(width: 20)
                    TextField("Name", text: $suggestion.name)
                        .textFieldStyle(.plain)
                        .font(.headline)
                    Spacer()
                    if existing {
                        Text("Adds to your group")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("^[\(kept) app](inflect: true)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 6)], spacing: 8) {
                    ForEach(suggestion.apps) { app in
                        let isLeftOut = leftOut.contains(app.id)
                        Button {
                            if isLeftOut { leftOut.remove(app.id) } else { leftOut.insert(app.id) }
                        } label: {
                            VStack(spacing: 3) {
                                Image(nsImage: Icons.app(app.url))
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                Text(app.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(width: 68)
                            .opacity(isLeftOut ? 0.3 : 1)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .help(isLeftOut ? Text("Click to include") : Text("Click to leave out"))
                    }
                }
            }
            .padding(6)
        }
        .opacity(isOn ? 1 : 0.5)
    }
}
