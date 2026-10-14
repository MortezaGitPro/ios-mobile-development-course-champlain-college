import SwiftUI
import SwiftData

@MainActor
struct ContentView: View {
    // @State preserves this observable reference for the screen's identity.
    @State private var vm: TodoListViewModel
    @State private var presentingAdd = false
    @State private var editingTodo: Todo?

    init(context: ModelContext) {
        // Dependency injection: receive the context, then supply the repository
        // to the ViewModel. The body never fetches, inserts, or saves data directly.
        _vm = State(initialValue: TodoListViewModel(
            repo: SwiftDataTodoRepository(context: context)
        ))
    }

    var body: some View {
        // @Bindable gives us $model.query and $model.sort. @State above owns the
        // reference; this local wrapper only exposes bindings to its properties.
        @Bindable var model = vm

        NavigationStack {
            VStack(spacing: 8) {
                HStack {
                    TextField("Search title or notes", text: $model.query)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Search title or notes")
                    Menu {
                        Picker("Sort tasks", selection: $model.sort) {
                            ForEach(TodoSort.allCases) { sort in
                                Text(sort.label).tag(sort)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityValue(model.sort.label)
                }
                .padding(.horizontal)

                List {
                    ForEach(model.items, id: \.id) { todo in
                        HStack(alignment: .top, spacing: 10) {
                            // Separate buttons keep completion and editing distinct
                            // and give VoiceOver a meaningful action for each.
                            Button { model.toggle(todo: todo) } label: {
                                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.large)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(todo.isDone ? "Mark \(todo.title) incomplete" : "Complete \(todo.title)")

                            Button { editingTodo = todo } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(todo.title).font(.headline).strikethrough(todo.isDone)
                                    if let notes = todo.notes, !notes.isEmpty {
                                        Text(notes).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    // Stack dates vertically to accommodate large text.
                                    Text("Created \(todo.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let due = todo.dueDate {
                                        Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the task editor")
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { model.delete(todo: todo) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if model.items.isEmpty && model.errorMessage == nil {
                        if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ContentUnavailableView("No tasks yet", systemImage: "checklist",
                                                   description: Text("Tap + to add your first task."))
                        } else {
                            ContentUnavailableView.search(text: model.query)
                        }
                    }
                }

                if let error = model.errorMessage {
                    VStack(spacing: 6) {
                        Text(error).foregroundStyle(.red)
                        Button("Retry loading") { model.reload() }
                    }
                    .font(.callout)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("My To-Dos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { presentingAdd = true } label: {
                        Label("Add task", systemImage: "plus.circle.fill")
                    }
                }
            }
            // Changing the query cancels and restarts the search task. The ViewModel
            // decides when to fetch; SwiftUI manages the task's screen lifetime.
            .task(id: model.query) {
                await model.searchAfterDebounce(for: model.query)
            }
            .sheet(isPresented: $presentingAdd) {
                AddEditTodoView(mode: .add) { title, notes, due in
                    try model.add(title: title, notes: notes, dueDate: due)
                }
            }
            .sheet(item: $editingTodo) { todo in
                AddEditTodoView(mode: .edit(todo)) { title, notes, due in
                    try model.update(todo: todo, title: title, notes: notes,
                                     dueDate: due, isDone: todo.isDone)
                }
            }
        }
    }
}

// MARK: - In-memory preview

/// A tiny preview host keeps setup and its container in the same file as the view.
/// Preview data never opens the application's disk-backed database.
@MainActor
private struct TodoListPreview: View {
    private let container: ModelContainer?
    private let setupError: String?

    init() {
        do {
            let schema = Schema([Todo.self])
            let configuration = ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
            )
            let store = try ModelContainer(for: schema, configurations: [configuration])
            store.mainContext.autosaveEnabled = false
            store.mainContext.insert(Todo(title: "Review MVVM", notes: "Follow a task from the View to the Repository."))
            store.mainContext.insert(Todo(title: "Prepare the classroom demo", dueDate: .now.addingTimeInterval(86_400)))
            store.mainContext.insert(Todo(title: "Create the project", isDone: true))
            try store.mainContext.save()
            container = store
            setupError = nil

            // Context comparison: ModelContext(store) would create another working
            // session sharing this same memory store. It would not create a new
            // database. Do not pass live models between contexts; fetch them there.
            // Creating another in-memory ModelContainer gives an independent store.
        } catch {
            container = nil
            setupError = error.localizedDescription
        }
    }

    var body: some View {
        if let container {
            ContentView(context: container.mainContext).modelContainer(container)
        } else {
            Text("Preview unavailable: \(setupError ?? "Unknown error")")
        }
    }
}

#Preview("Sample tasks — memory only") {
    TodoListPreview()
}
