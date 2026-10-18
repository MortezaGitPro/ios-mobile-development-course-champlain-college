import Foundation
import Observation

/// All screen state belongs to the main actor. The repository handles data work;
/// suspending at `await` lets the UI keep responding while that work completes.
@MainActor
@Observable
final class NewsViewModel {
    private(set) var articles: [Article] = []
    private(set) var likedArticles: [Article] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var slowNetworkHint = false
    private(set) var errorMessage: String?
    private(set) var saveErrorMessage = ""

    // @Bindable in the view provides bindings to these editable properties.
    var searchText = ""
    var isShowingSaveError = false

    private let repository: any NewsRepository

    // Coordination data does not need to trigger a SwiftUI redraw.
    @ObservationIgnored private var activeLoadID = UUID()

    init(repository: any NewsRepository) {
        self.repository = repository
    }

    var likedIDs: Set<String> {
        Set(likedArticles.map(\.id))
    }

    func filteredArticles(showingLiked: Bool) -> [Article] {
        let items = showingLiked ? likedArticles : articles
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(query)
                || ($0.description ?? "").localizedCaseInsensitiveContains(query)
                || ($0.source?.name ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    /// This method is itself async: its caller can await completion or cancel it.
    func load(country: String, category: String, showingLiked: Bool) async {
        guard !Task.isCancelled, !isSaving else { return }
        let loadID = UUID()
        activeLoadID = loadID
        isLoading = true
        errorMessage = nil
        slowNetworkHint = false

        // An older request must not clear a newer request's loading state.
        defer {
            if activeLoadID == loadID {
                isLoading = false
                slowNetworkHint = false
            }
        }

        do {
            if showingLiked {
                // Saved mode makes no NewsAPI request and works offline.
                let saved = try await repository.loadLiked()
                try Task.checkCancellation()
                guard activeLoadID == loadID else { return }
                likedArticles = saved
            } else {
                try await loadHeadlines(country: country, category: category, loadID: loadID)
            }
        } catch is CancellationError {
            // Switching filters or leaving the screen is not an error to display.
        } catch {
            guard !Task.isCancelled, activeLoadID == loadID else { return }
            errorMessage = error.localizedDescription
        }
    }

    private enum LoadEvent: Sendable {
        case slow
        case loaded(articles: [Article], liked: [Article])
    }

    private func loadHeadlines(country: String, category: String, loadID: UUID) async throws {
        let repository = self.repository

        // TaskGroup keeps the fetch and slow-feedback timer under one parent.
        // Its children finish or are cancelled before this method returns.
        try await withThrowingTaskGroup(of: LoadEvent.self) { group in
            group.addTask {
                // Two independent data sources can start together. async let
                // creates child tasks; awaiting the tuple collects both results.
                async let headlines = repository.topHeadlines(country: country, category: category)
                async let saved = repository.loadLiked()
                let (articles, liked) = try await (headlines, saved)
                return .loaded(articles: articles, liked: liked)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                return .slow
            }
            defer { group.cancelAll() }

            // Results arrive in completion order, so the timer can update the
            // hint first. A finished fetch cancels any remaining timer immediately.
            for try await event in group {
                try Task.checkCancellation()
                guard activeLoadID == loadID else { return }
                switch event {
                case .slow:
                    slowNetworkHint = true
                case .loaded(let headlines, let liked):
                    articles = headlines
                    likedArticles = liked
                    return
                }
            }
        }
    }

    func toggleLike(_ article: Article) async {
        // Serialize taps and keep saved-state snapshots consistent during loads.
        guard !isSaving, !isLoading else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await repository.toggleLike(article)
            likedArticles = try await repository.loadLiked()
        } catch {
            saveErrorMessage = error.localizedDescription
            isShowingSaveError = true
        }
    }
}
