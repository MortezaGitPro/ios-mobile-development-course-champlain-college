import Foundation

/// Codable supports both the API response and JSON storage of saved articles.
/// Sendable allows these values to travel safely between tasks and actors.
struct Article: Codable, Identifiable, Hashable, Sendable {
    let title: String?
    let description: String?
    let url: String?
    let urlToImage: String?
    let publishedAt: String?
    let source: Source?

    // A nested Swift type matches the nested `source` object in the JSON.
    struct Source: Codable, Hashable, Sendable {
        let id: String?
        let name: String?
    }

    var id: String {
        if let articleURL { return articleURL.absoluteString }

        // Missing URLs still need an ID that stays the same after every read.
        // Length prefixes prevent separators inside the text from confusing IDs.
        return [source?.name, title, publishedAt, description, urlToImage].map {
            let text = $0 ?? ""
            return "\(text.utf8.count):\(text)"
        }.joined(separator: "|")
    }

    var articleURL: URL? { Self.webURL(from: url) }
    var imageURL: URL? { Self.webURL(from: urlToImage) }

    var publishedDate: Date? {
        guard let publishedAt else { return nil }
        return try? Date(publishedAt, strategy: .iso8601)
    }

    // Only web links with a host are suitable for the Open button and images.
    private static func webURL(from text: String?) -> URL? {
        guard let text,
              let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty
        else {
            return nil
        }
        return url
    }
}
