import Foundation
import Observation

/// Owns screen state and translates user intentions into repository operations.
/// @Observable lets SwiftUI track properties read by a view's body.
/// @MainActor isolates UI state and repository calls to the main actor.
@MainActor
@Observable
final class TodoListViewModel {
    // MARK: - Screen state
    private(set) var items: [Todo] = []
    var query = ""
    var sort: TodoSort = .newest {
        didSet { if sort != oldValue { reload() } }
    }
    private(set) var errorMessage: String?

    // This dependency is implementation detail, not observable screen state.
    @ObservationIgnored private let repo: any TodoRepository

    init(repo: any TodoRepository) {
        self.repo = repo
        reload()
    }

    // MARK: - Load and search

    func reload() {
        do {
            items = try repo.fetchTodos(query: query, sort: sort)
            errorMessage = nil
        } catch {
            // Preserve the last good list and show why refresh failed.
            errorMessage = "Could not load tasks: \(error.localizedDescription)"
        }
    }

    /// The view calls this using .task(id: query). New input cancels the previous
    /// task; disappearance also cancels it. Sleeping suspends without blocking UI.
    func searchAfterDebounce(for requestedQuery: String) async {
        do {
            if !requestedQuery.isEmpty { try await Task.sleep(for: .milliseconds(250)) }
            try Task.checkCancellation()
        } catch {
            return // Cancellation is expected when typing, not a storage error.
        }
        guard requestedQuery == query else { return }
        reload()
    }

    // MARK: - User actions

    /// A write error propagates to the editor so it can keep the user's input.
    /// A successful write followed by a failed reload is reported as a load error:
    /// the editor should close because the task was already saved successfully.
    func add(title: String, notes: String?, dueDate: Date?) throws {
        try repo.add(title: title, notes: notes, dueDate: dueDate)
        reload()
    }

    func update(todo: Todo, title: String, notes: String?, dueDate: Date?, isDone: Bool) throws {
        try repo.update(todo: todo, title: title, notes: notes, dueDate: dueDate, isDone: isDone)
        reload()
    }

    func toggle(todo: Todo) {
        do {
            try repo.toggle(todo)
            reload()
        } catch {
            errorMessage = "Could not change completion: \(error.localizedDescription)"
        }
    }

    func delete(todo: Todo) {
        do {
            try repo.delete(todo)
            reload()
        } catch {
            errorMessage = "Could not delete the task: \(error.localizedDescription)"
        }
    }
}
