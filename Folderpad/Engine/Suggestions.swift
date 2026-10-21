import Foundation

nonisolated struct GroupSuggestion: Identifiable, Sendable {
    let id: String
    var name: String
    let symbol: String
    var apps: [InstalledApp]
}

/// Proposes groups from each app's App Store category, so a fresh Mac can be sorted in one go.
nonisolated enum Suggestions {
    private struct Bucket {
        let id: String
        let name: String
        let symbol: String
        let categories: Set<String>
    }

    private static var buckets: [Bucket] {
        [
            Bucket(id: "developer", name: "Developer", symbol: "hammer",
                   categories: ["developer-tools"]),
            Bucket(id: "productivity", name: "Productivity", symbol: "checklist",
                   categories: ["productivity", "business"]),
            Bucket(id: "creative", name: "Creative", symbol: "paintpalette",
                   categories: ["graphics-design", "photography", "video"]),
            Bucket(id: "social", name: "Social", symbol: "bubble.left.and.bubble.right",
                   categories: ["social-networking"]),
            Bucket(id: "entertainment", name: "Entertainment", symbol: "play.rectangle",
                   categories: ["entertainment", "music"]),
            Bucket(id: "games", name: "Games", symbol: "gamecontroller",
                   categories: ["games"]),
            Bucket(id: "utilities", name: "Utilities", symbol: "wrench.and.screwdriver",
                   categories: ["utilities"]),
            Bucket(id: "education", name: "Education", symbol: "graduationcap",
                   categories: ["education", "reference", "books"]),
            Bucket(id: "finance", name: "Finance", symbol: "chart.line.uptrend.xyaxis",
                   categories: ["finance"]),
            Bucket(id: "lifestyle", name: "Lifestyle", symbol: "leaf",
                   categories: ["lifestyle", "news", "weather", "travel", "sports", "healthcare-fitness",
                                "medical", "food-and-drink", "navigation"]),
        ]
    }

    /// AI assistants mostly file themselves under Productivity, so they are told apart by name.
    private static let assistantNames = [
        "chatgpt", "claude", "gemini", "perplexity", "copilot", "ollama", "lm studio",
        "msty", "grok", "deepseek", "le chat", "poe",
    ]

    /// Helpers that sit in Applications but are not opened by hand.
    private static let skippedWords = ["uninstall", "helper", "handler", "updater"]

    /// Only categories with at least two apps make a group worth having.
    static func make(from apps: [InstalledApp], includeSystem: Bool) -> [GroupSuggestion] {
        var byBucket: [String: [InstalledApp]] = [:]
        for app in apps where includeSystem || !app.isSystem {
            let name = app.name.lowercased()
            if skippedWords.contains(where: name.contains) { continue }
            if assistantNames.contains(where: { name == $0 || name.hasPrefix($0 + " ") }) {
                byBucket["ai", default: []].append(app)
            } else if let bucket = bucket(for: app.category) {
                byBucket[bucket.id, default: []].append(app)
            }
        }

        let assistant = Bucket(id: "ai", name: "AI", symbol: "sparkles", categories: [])
        return ([assistant] + buckets)
            .compactMap { bucket in
                guard let members = byBucket[bucket.id], members.count >= 2 else { return nil }
                return GroupSuggestion(id: bucket.id, name: bucket.name, symbol: bucket.symbol, apps: members)
            }
            .sorted { $0.apps.count > $1.apps.count }
    }

    private static func bucket(for category: String?) -> Bucket? {
        guard var category = category?.lowercased() else { return nil }
        category = category.replacingOccurrences(of: "public.app-category.", with: "")
        // Every game genre ("action-games", "puzzle-games", …) goes with Games.
        if category.hasSuffix("-games") { category = "games" }
        return buckets.first { $0.categories.contains(category) }
    }
}
