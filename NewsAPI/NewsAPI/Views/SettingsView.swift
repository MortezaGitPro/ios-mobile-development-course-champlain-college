import SwiftUI

/// Bindings edit the parent's @AppStorage values; they do not create a second
/// copy of the preferences. Changes are persisted by the parent automatically.
@MainActor
struct SettingsView: View {
    @Binding var country: String
    @Binding var category: String
    @Binding var showLikedByDefault: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Picker("Country", selection: $country) {
                    Text("United States").tag(ConfigManager.defaultCountry)
                }
                .disabled(true)

                Picker("Category", selection: $category) {
                    ForEach(ConfigManager.categories, id: \.self) { category in
                        Text(category.capitalized).tag(category)
                    }
                }
            } header: {
                Text("News")
            } footer: {
                Text("NewsAPI currently lists U.S. top headlines. Choose a category to filter them.")
            }

            Section {
                Toggle("Show saved articles by default", isOn: $showLikedByDefault)
            } footer: {
                Text("Applied at the next app launch. Saved summaries work offline; images and full articles need internet access.")
            }

            Section("About") {
                LabeledContent("App Version", value: Bundle.main.appVersionDisplay)
                LabeledContent("Developer", value: "Morteza Khanjanzadeh")
                if let url = URL(string: "https://newsapi.org") {
                    Link("NewsAPI", destination: url)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

extension Bundle {
    var appVersionDisplay: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
