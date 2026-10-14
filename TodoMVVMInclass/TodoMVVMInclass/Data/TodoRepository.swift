import Foundation
import SwiftData

// MARK: - Sorting choices

enum TodoSort: String, CaseIterable, Identifiable {
    case newest, oldest, titleAZ, titleZA, dueSoon
    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .titleAZ: "Title A–Z"
        case .titleZA: "Title Z–A"
        case .dueSoon: "Due soon"
        }
    }
}

// MARK: - Repository contract

/// A repository hides storage details from the ViewModel. Receiving a repository
/// through an initializer is dependency injection: the caller supplies what is needed.
///
/// ModelContext.fetch/save are synchronous, so these functions use throws, not
/// async. Adding async does not move database work to a background thread.
/// A network repository would need an asynchronous contract for real network waits.
@MainActor
protocol TodoRepository {
    func fetchTodos(query: String?, sort: TodoSort) throws -> [Todo]
    func add(title: String, notes: String?, dueDate: Date?) throws
    func update(todo: Todo, title: String, notes: String?, dueDate: Date?, isDone: Bool) throws
    func toggle(_ todo: Todo) throws
    func delete(_ todo: Todo) throws
}

// MARK: - SwiftData implementation

/// Main-actor isolation keeps this UI-facing context and its live models together.
/// Both the protocol and implementation declare the same isolation contract.
@MainActor
final class SwiftDataTodoRepository: TodoRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        // Every user action explicitly saves, allowing us to report save failures.
        context.autosaveEnabled = false
    }

    func fetchTodos(query: String?, sort: TodoSort) throws -> [Todo] {
        let term = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var predicate: Predicate<Todo>?
        if !term.isEmpty {
            // Search title OR optional notes. A missing note does not match.
            predicate = #Predicate<Todo> { todo in
                todo.title.localizedStandardContains(term) ||
                (todo.notes?.localizedStandardContains(term) ?? false)
            }
        }

        let descriptors: [SortDescriptor<Todo>]
        switch sort {
        case .newest:
            descriptors = [SortDescriptor(\Todo.createdAt, order: .reverse)]
        case .oldest:
            descriptors = [SortDescriptor(\Todo.createdAt)]
        case .titleAZ:
            descriptors = [SortDescriptor(\Todo.title), SortDescriptor(\Todo.createdAt, order: .reverse)]
        case .titleZA:
            descriptors = [SortDescriptor(\Todo.title, order: .reverse), SortDescriptor(\Todo.createdAt, order: .reverse)]
        case .dueSoon:
            descriptors = [SortDescriptor(\Todo.dueDate), SortDescriptor(\Todo.createdAt, order: .reverse)]
        }

        let descriptor = FetchDescriptor<Todo>(predicate: predicate, sortBy: descriptors)
        let todos = try context.fetch(descriptor)
        // Optional dates may sort before actual dates in the store. Move undated
        // tasks to the end while retaining the fetched order within each group.
        // This small classroom list is fetched in full; large datasets need paging.
        if sort == .dueSoon {
            return todos.filter { $0.dueDate != nil } + todos.filter { $0.dueDate == nil }
        }
        return todos
    }

    // MARK: - Create, update, toggle, and delete

    func add(title: String, notes: String?, dueDate: Date?) throws {
        let validTitle = try validatedTitle(title)
        let todo = Todo(title: validTitle, notes: normalizedNotes(notes), dueDate: dueDate)
        context.insert(todo) // Stage the insert; save commits it.
        try saveChanges()
    }

    func update(todo: Todo, title: String, notes: String?, dueDate: Date?, isDone: Bool) throws {
        // Validate before changing a live model. Identity/creation date stay intact.
        let validTitle = try validatedTitle(title)
        todo.title = validTitle
        todo.notes = normalizedNotes(notes)
        todo.dueDate = dueDate
        todo.isDone = isDone
        try saveChanges()
    }

    func toggle(_ todo: Todo) throws {
        todo.isDone.toggle()
        try saveChanges()
    }

    func delete(_ todo: Todo) throws {
        context.delete(todo)
        try saveChanges()
    }

    // MARK: - Validation and saving

    private func validatedTitle(_ title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TodoInputError.emptyTitle }
        return trimmed
    }

    private func normalizedNotes(_ notes: String?) -> String? {
        guard let text = notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    private func saveChanges() throws {
        do {
            try context.save()
        } catch {
            // Restore the last saved state instead of displaying an unsaved change
            // as successful. rollback affects ALL pending work in this context.
            // Here only the repository writes, and each action saves immediately.
            context.rollback()
            throw error
        }
    }
}

private enum TodoInputError: LocalizedError {
    case emptyTitle
    var errorDescription: String? { "Enter a title before saving." }
}
