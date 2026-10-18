import SwiftUI

/// Displays state from the ViewModel and sends user actions back to it.
@MainActor
struct ContentView: View {
    // The App owns this object; @Bindable exposes bindings such as $vm.searchText.
    @Bindable var vm: NewsViewModel

    @State private var showingLiked: Bool
    @State private var showSettings = false
    @State private var reloadID = UUID()

    // Small preferences persist automatically in this app's UserDefaults.
    @AppStorage("country") private var country = ConfigManager.defaultCountry
    @AppStorage("category") private var category = "general"
    @AppStorage("showLikedByDefault") private var showLikedByDefault = false

    init(vm: NewsViewModel) {
        self.vm = vm
        // Apply the saved default once when this screen's state is first created.
        _showingLiked = State(initialValue: UserDefaults.standard.bool(forKey: "showLikedByDefault"))
    }

    private var displayedArticles: [Article] {
        vm.filteredArticles(showingLiked: showingLiked)
    }

    // Search stays local. Only the edition, category, mode, or Reload starts a load.
    private var loadKey: String {
        "\(country)|\(category)|\(showingLiked)|\(reloadID)"
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    loadingView
                } else if let message = vm.errorMessage {
                    errorView(message)
                } else if displayedArticles.isEmpty {
                    emptyView
                } else {
                    List(displayedArticles) { article in
                        articleRow(article)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(showingLiked ? "Saved Articles" : "Top Headlines")
            .searchable(text: $vm.searchText, prompt: "Search loaded articles")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(showingLiked ? "Headlines" : "Saved") {
                        showingLiked.toggle()
                    }
                    .disabled(vm.isSaving)

                    Button("Reload", systemImage: "arrow.clockwise") {
                        reloadID = UUID()
                    }
                    .disabled(vm.isSaving)

                    Button("Settings", systemImage: "gearshape") {
                        showSettings = true
                    }
                    .disabled(vm.isSaving)
                }
            }
            // SwiftUI cancels and restarts this task when its ID changes, and
            // cancels it when the screen disappears. Await the actual load here.
            .task(id: loadKey) {
                if country != ConfigManager.defaultCountry {
                    country = ConfigManager.defaultCountry
                    return
                }
                if !ConfigManager.categories.contains(category) {
                    category = "general"
                    return
                }
                await vm.load(country: country, category: category, showingLiked: showingLiked)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(
                        country: $country,
                        category: $category,
                        showLikedByDefault: $showLikedByDefault
                    )
                }
            }
            .alert("Could not update saved articles", isPresented: $vm.isShowingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(vm.saveErrorMessage)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView(showingLiked ? "Loading saved articles…" : "Loading headlines…")
            if vm.slowNetworkHint {
                Text("This is taking longer than usual. Still trying…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load News", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") { reloadID = UUID() }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        if !vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: vm.searchText)
        } else {
            ContentUnavailableView(
                showingLiked ? "No Saved Articles" : "No Headlines",
                systemImage: showingLiked ? "bookmark" : "newspaper",
                description: Text(showingLiked
                    ? "Save an article from Top Headlines to read its summary offline."
                    : "Try another category in Settings, or reload later.")
            )
        }
    }

    private func articleRow(_ article: Article) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // AsyncImage exposes loading, success, and failure phases. Missing or
            // offline images get a placeholder; article text remains available.
            AsyncImage(url: article.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.secondary.opacity(0.1)
                        Image(systemName: "newspaper")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(article.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(3)

                if let description = article.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack {
                    if let source = article.source?.name {
                        Text(source).lineLimit(1)
                    }
                    if let date = article.publishedDate {
                        Text(date, style: .date)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                HStack {
                    let isLiked = vm.likedIDs.contains(article.id)
                    Button(isLiked ? "Saved" : "Save",
                           systemImage: isLiked ? "bookmark.fill" : "bookmark") {
                        // A button action is synchronous. Task bridges it to an
                        // async method; saving is short and can finish independently.
                        Task { await vm.toggleLike(article) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isSaving || vm.isLoading)
                    .accessibilityLabel(isLiked ? "Unsave article" : "Save article")

                    if let url = article.articleURL {
                        Link("Open", destination: url)
                            .buttonStyle(.bordered)
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 6)
    }
}
