import Foundation
import SwiftData

/// One persisted task. @Model generates SwiftData persistence and observation
/// behavior. Model instances are reference types, so editing a property changes
/// that same object; the editor therefore uses separate @State values while typing.
@Model
final class Todo {
    // Stable identity survives edits. Two tasks may have the same title.
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var isDone: Bool
    var createdAt: Date
    var dueDate: Date?

    init(title: String, notes: String? = nil, isDone: Bool = false,
         createdAt: Date = .now, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.isDone = isDone
        self.createdAt = createdAt
        self.dueDate = dueDate
    }
}
