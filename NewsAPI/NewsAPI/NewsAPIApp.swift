import SwiftUI

/// The app creates its dependencies once and passes them to the first screen.
@main
@MainActor
struct NewsAPIApp: App {
    // @State owns this @Observable object for the lifetime of the app's UI.
    @State private var viewModel: NewsViewModel

    init() {
        let local = LocalNewsRepository()
        let remote = RemoteNewsRepository(
            apiKey: ConfigManager.newsApiKey,
            local: local
        )
        _viewModel = State(initialValue: NewsViewModel(repository: remote))

        // To explore the repository pattern without the internet, pass `local`
        // to NewsViewModel instead. Its headlines come from saved articles.
    }

    var body: some Scene {
        WindowGroup {
            ContentView(vm: viewModel)
        }
    }
}
