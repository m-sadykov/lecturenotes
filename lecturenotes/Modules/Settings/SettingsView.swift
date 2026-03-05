import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Language") {
                    Picker("Output language", selection: $viewModel.selectedLanguage) {
                        ForEach(viewModel.languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                }

                Section("Storage") {
                    Toggle("Delete audio after processing", isOn: $viewModel.deleteAudioAfterProcessing)
                }

                Section("Purchases") {
                    Button("Restore purchases", systemImage: "arrow.clockwise") {}
                }

                Section("Support") {
                    Button("Contact support", systemImage: "envelope") {}
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
