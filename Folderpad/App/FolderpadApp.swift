import AppKit
import SwiftUI

/// An ordinary app: open it, arrange groups, quit. What it builds (folders of aliases in
/// Applications, folder tiles in the Dock) stays after it quits, like folders made by hand.
@main
struct FolderpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var library: Library

    init() {
        _library = State(initialValue: Library.shared)
    }

    var body: some Scene {
        Window("Folderpad", id: "main") {
            ContentView()
                .environment(library)
                .frame(minWidth: 780, minHeight: 500)
        }
        .defaultSize(width: 1000, height: 660)
        .commands {
            FolderpadCommands(library: library)
        }

        Settings {
            SettingsView()
                .environment(library)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        DebugSnapshots.startIfRequested()
        #endif
    }

    /// Nothing runs in the background, so closing the window quits.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct FolderpadCommands: Commands {
    let library: Library

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Folderpad") { showAboutPanel() }
        }
        CommandGroup(replacing: .newItem) {
            Button("New Group…") { library.sheet = .newGroup }
                .keyboardShortcut("n")
            Button("Suggest Groups…") { library.sheet = .suggestions }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Pin Folder to Dock…") { chooseFoldersToPin(into: library) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
        }
        CommandGroup(before: .sidebar) {
            Button("Reload") {
                library.reload()
                Task { await library.scanApps() }
            }
            .keyboardShortcut("r")
            Divider()
        }
    }

    /// The standard About panel, filled from the bundle so the version is always the real one.
    @MainActor private func showAboutPanel() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Folderpad",
            .applicationVersion: version,
            .version: build,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 falconsw",
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
