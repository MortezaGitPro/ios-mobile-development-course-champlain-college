import SwiftUI

/// A single editor supports both creating a task and editing an existing one.
/// Identifiable supplies a stable identifier if used with .sheet(item:).
enum Mode: Identifiable {
    case add
    case edit(Todo)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let todo): "edit-\(todo.id)"
        }
    }
}

@MainActor
struct AddEditTodoView: View {
    let mode: Mode
    // The editor forwards values, rather than knowing how to access a database.
    let onSave: (String, String?, Date?) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var saveError: String?

    init(mode: Mode, onSave: @escaping (String, String?, Date?) throws -> Void) {
        self.mode = mode
        self.onSave = onSave
        // Copy into local state once for this editor identity. Typing does not
        // modify the live Todo. Cancel or swipe-dismiss simply discards these values.
        // _title accesses the State wrapper; title accesses its stored value.
        if case let .edit(todo) = mode {
            _title = State(initialValue: todo.title)
            _notes = State(initialValue: todo.notes ?? "")
            _hasDueDate = State(initialValue: todo.dueDate != nil)
            _dueDate = State(initialValue: todo.dueDate ?? .now)
        } else {
            _title = State(initialValue: "")
            _notes = State(initialValue: "")
            _hasDueDate = State(initialValue: false)
            _dueDate = State(initialValue: .now)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var modeTitle: String {
        switch mode {
        case .add: "New To-Do"
        case .edit: "Edit To-Do"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title, axis: .vertical)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                // $ creates a binding to state owned by this editor. The small
                // child below borrows those values instead of storing another copy.
                DueDateFields(hasDueDate: $hasDueDate, dueDate: $dueDate)
                if let saveError {
                    Section("Could not save") {
                        Text(saveError).foregroundStyle(.red)
                        Text("Your changes are still here. Try Save again or Cancel.")
                    }
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private func save() {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try onSave(trimmedTitle, cleanNotes.isEmpty ? nil : cleanNotes,
                       hasDueDate ? dueDate : nil)
            dismiss() // Dismiss only after the write succeeds.
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// A short reusable @Binding example, kept in this file to keep the project small.
/// @Binding does not own these values: AddEditTodoView owns them with @State.
private struct DueDateFields: View {
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date

    var body: some View {
        Section("Due date") {
            Toggle("Set due date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("Due", selection: $dueDate, displayedComponents: .date)
            }
        }
    }
}

#Preview("New task form") {
    // A UI-only preview: saving performs no database operation.
    AddEditTodoView(mode: .add) { _, _, _ in }
}
