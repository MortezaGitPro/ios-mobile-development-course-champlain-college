import SwiftUI
import SwiftData

/// Application entry point. Open TodoMVVMInclass.xcodeproj, select an iPhone
/// Simulator running iOS 17 or later, and press Command-R.
///
/// Learning flow: View → ViewModel → Repository → SwiftData.
/// SwiftUI builds the interface; Observation tracks screen state; SwiftData stores
/// tasks. These Apple frameworks are included in the SDK; no packages are needed.
@main
@MainActor
struct ToDoMVVMApp: App {
    private let sharedModelContainer: ModelContainer?
    private let storageError: String?

    init() {
        do {
            // Container = schema + storage configuration. Disk-backed storage keeps
            // tasks between launches of the same app installation.
            let schema = Schema([Todo.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            container.mainContext.autosaveEnabled = false
            sharedModelContainer = container
            storageError = nil
        } catch {
            // Do not crash or silently switch to temporary storage when opening
            // the saved database fails. Preserve the store and display the error.
            sharedModelContainer = nil
            storageError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                // Context = a working session that fetches, tracks, and saves models.
                // mainContext is already associated with the main actor. Inject it
                // into the screen, which constructs its ViewModel and repository.
                ContentView(context: container.mainContext)
                    .modelContainer(container)
            } else {
                ContentUnavailableView(
                    "Storage unavailable",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(storageError ?? "Close the app and try again.")
                )
            }
        }
    }
}
