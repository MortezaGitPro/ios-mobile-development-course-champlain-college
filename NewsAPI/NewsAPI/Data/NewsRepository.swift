import Foundation

/// A contract shared by the online and local data sources.
/// The ViewModel uses this protocol instead of depending on a concrete repository.
protocol NewsRepository: Sendable {
    func topHeadlines(country: String, category: String) async throws -> [Article]
    func loadLiked() async throws -> [Article]

    /// Returns true when saved, or false when removed from saved articles.
    func toggleLike(_ article: Article) async throws -> Bool
}
