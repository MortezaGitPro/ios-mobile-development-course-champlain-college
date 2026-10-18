import Foundation

/// A namespace for the endpoint, supported settings, and bundled configuration.
enum ConfigManager {
    static let newsBaseURL = "https://newsapi.org/v2"
    static let defaultCountry = "us"
    static let categories = [
        "general", "business", "entertainment", "health",
        "science", "sports", "technology"
    ]

    // NewsAPI currently documents only `us` for /top-headlines (October 2026).
    // Recheck https://newsapi.org/docs/endpoints/top-headlines before adding countries.

    /// Reads configuration from the app bundle, not from a Swift source file.
    static var newsApiKey: String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let secrets = try? PropertyListDecoder().decode(Secrets.self, from: data)
        else {
            return ""
        }

        let key = secrets.newsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return key == "YOUR_NEWS_API_KEY" ? "" : key
    }

    // For a fresh Git clone, copy Resources/Secrets.example.plist to
    // Resources/Secrets.plist and enter your own key before building.
    // .gitignore keeps this file out of Git; it is still readable in a built app.
    // A production app should keep a private provider key on its own server.
    private struct Secrets: Decodable {
        let newsAPIKey: String

        enum CodingKeys: String, CodingKey {
            case newsAPIKey = "NEWS_API_KEY"
        }
    }
}
