import Foundation

/// Downloads headlines and delegates saved-article operations to local storage.
/// Its immutable, Sendable dependencies can be shared safely between tasks.
final class RemoteNewsRepository: NewsRepository {
    private let apiKey: String
    private let local: LocalNewsRepository
    private let session: URLSession

    init(apiKey: String, local: LocalNewsRepository) {
        self.apiKey = apiKey
        self.local = local

        let configuration = URLSessionConfiguration.default
        // Request timeout measures inactivity; the resource timeout bounds the
        // whole operation, including waiting for connectivity.
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func topHeadlines(country: String, category: String) async throws -> [Article] {
        try Task.checkCancellation()
        guard !apiKey.isEmpty else { throw NewsError.apiKeyMissing }
        guard country == ConfigManager.defaultCountry else {
            throw NewsError.unsupportedCountry
        }
        guard ConfigManager.categories.contains(category) else {
            throw NewsError.unsupportedCategory
        }

        // URLComponents encodes query values without manually joining strings.
        guard var components = URLComponents(
            string: ConfigManager.newsBaseURL + "/top-headlines"
        ) else { throw NewsError.badURL }

        components.queryItems = [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "pageSize", value: "20")
        ]
        guard let url = components.url else { throw NewsError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Keep the key out of the URL and avoid logging the request headers.
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        do {
            // URLSession performs network I/O asynchronously. `await` suspends
            // this task without blocking the UI; it does not create a new thread.
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()

            guard let http = response as? HTTPURLResponse else {
                throw NewsError.invalidResponse
            }

            let decoder = JSONDecoder()
            let apiError = try? decoder.decode(NewsAPIErrorPayload.self, from: data)

            // URLSession does not throw merely because the status is 401 or 500.
            // Inspect HTTP status before trying to decode a success response.
            guard (200...299).contains(http.statusCode) else {
                throw NewsError.http(http.statusCode, server: apiError?.message)
            }
            if apiError?.status == "error" {
                throw NewsError.api(apiError?.message)
            }

            let result = try decoder.decode(NewsResponse.self, from: data)
            guard result.status == "ok" else { throw NewsError.invalidResponse }

            // Stable IDs + de-duplication keep SwiftUI rows and saved state in sync.
            var seen = Set<String>()
            return result.articles.filter { article in
                article.title?.trimmingCharacters(in: .whitespacesAndNewlines) != "[Removed]"
                    && seen.insert(article.id).inserted
            }
            // An empty array is a successful request with no results, not a crash.
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            // URLSession can report cancellation as a URLError instead.
            if error.code == .cancelled { throw CancellationError() }
            throw NewsError.network(error.code)
        } catch is DecodingError {
            throw NewsError.decoding
        }
    }

    func loadLiked() async throws -> [Article] {
        try await local.loadLiked()
    }

    func toggleLike(_ article: Article) async throws -> Bool {
        try await local.toggleLike(article)
    }
}

/// Only the networking layer needs the shape of an API error response.
private struct NewsAPIErrorPayload: Decodable {
    let status: String
    let code: String?
    let message: String?
}
