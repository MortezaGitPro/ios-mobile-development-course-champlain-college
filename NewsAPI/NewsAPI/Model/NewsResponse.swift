import Foundation

/// The outer JSON object contains an array of nested Article objects.
/// JSONDecoder ignores extra API fields that our models do not declare.
struct NewsResponse: Decodable, Sendable {
    let status: String
    let totalResults: Int
    let articles: [Article]
}
