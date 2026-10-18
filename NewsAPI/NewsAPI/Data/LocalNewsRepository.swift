import Foundation

/// An actor serializes access to saved data so concurrent tasks cannot overwrite
/// each other's read-modify-write operations. It is separate from the UI actor.
actor LocalNewsRepository: NewsRepository {
    private let key = "liked_articles_v1"

    // UserDefaults lives inside this app's sandbox. It suits this small teaching
    // example; larger collections belong in a database or a dedicated file.
    private let defaults = UserDefaults.standard

    // The local implementation can supply saved articles in place of API news.
    func topHeadlines(country: String, category: String) async throws -> [Article] {
        try Task.checkCancellation()
        return try read()
    }

    // These actor-isolated methods have no suspension points internally.
    // Callers outside the actor still use `try await` to access them safely.
    func loadLiked() throws -> [Article] {
        try read()
    }

    func toggleLike(_ article: Article) throws -> Bool {
        var articles = try read()
        let isNowLiked: Bool

        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles.remove(at: index)
            isNowLiked = false
        } else {
            articles.insert(article, at: 0)
            isNowLiked = true
        }

        try write(articles)
        return isNowLiked
    }

    private func read() throws -> [Article] {
        // No value is normal on the first launch; damaged JSON is a real error.
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            let articles = try JSONDecoder().decode([Article].self, from: data)
            var seen = Set<String>()
            return articles.filter { seen.insert($0.id).inserted }
        } catch {
            // Keep the stored bytes rather than silently replacing them with [].
            throw NewsError.storageRead
        }
    }

    private func write(_ articles: [Article]) throws {
        do {
            // Swift objects -> JSON Data -> UserDefaults.
            let data = try JSONEncoder().encode(articles)
            defaults.set(data, forKey: key)
        } catch {
            throw NewsError.storageWrite
        }
    }
}
