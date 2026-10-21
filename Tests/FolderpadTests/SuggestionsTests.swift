import Foundation
import Testing
@testable import Folderpad

struct SuggestionsTests {
    private func app(_ name: String, _ category: String?, system: Bool = false) -> InstalledApp {
        let folder = system ? "/System/Applications" : "/Applications"
        return InstalledApp(url: URL(fileURLWithPath: "\(folder)/\(name).app"), name: name, bundleID: nil, category: category)
    }

    @Test func groupsByCategoryAndDropsLoneApps() {
        let apps = [
            app("Xcode", "public.app-category.developer-tools"),
            app("Cursor", "public.app-category.developer-tools"),
            app("Figma", "public.app-category.graphics-design"),
            app("Untitled", nil),
        ]
        let suggestions = Suggestions.make(from: apps, includeSystem: false)
        #expect(suggestions.map(\.id) == ["developer"])
        #expect(suggestions.first?.apps.map(\.name) == ["Xcode", "Cursor"])
    }

    @Test func assistantsAreToldApartByName() {
        let apps = [
            app("ChatGPT", "public.app-category.productivity"),
            app("Claude", "public.app-category.productivity"),
            app("Claude Code URL Handler", "public.app-category.developer-tools"),
            app("Notion", "public.app-category.productivity"),
        ]
        let suggestions = Suggestions.make(from: apps, includeSystem: false)
        #expect(suggestions.first { $0.id == "ai" }?.apps.map(\.name) == ["ChatGPT", "Claude"])
        #expect(!suggestions.contains { $0.id == "productivity" })
    }

    @Test func gameGenresJoinGamesAndAppleAppsAreOptional() {
        let apps = [
            app("Chess", "public.app-category.board-games", system: true),
            app("Steam", "public.app-category.games"),
            app("Solitaire", "public.app-category.card-games"),
        ]
        #expect(Suggestions.make(from: apps, includeSystem: false).first?.apps.map(\.name) == ["Steam", "Solitaire"])
        #expect(Suggestions.make(from: apps, includeSystem: true).first?.apps.count == 3)
    }
}
