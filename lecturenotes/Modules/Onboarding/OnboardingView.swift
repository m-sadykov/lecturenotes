import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState
    @State private var selectedLanguage = "English"

    private let languages = ["English", "Русский", "Қазақша"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Lecture Notes AI") {
                    Text("Record lectures, get AI notes, flashcards, and quiz practice.")
                }

                Section("Permissions") {
                    Label("Microphone access required for recording", systemImage: "mic.fill")
                }

                Section("Output Language") {
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                }

                Section {
                    Button("Continue", systemImage: "arrow.right.circle.fill") {
                        appState.needsOnboarding = false
                    }
                }
            }
            .navigationTitle("Welcome")
        }
    }
}

#Preview {
    OnboardingView(appState: AppState())
}
