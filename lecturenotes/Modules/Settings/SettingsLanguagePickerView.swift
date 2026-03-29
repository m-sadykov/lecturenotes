import SwiftUI

struct SettingsLanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List(AppLanguage.allCases) { language in
                Button {
                    appState.selectedLanguage = language
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: language.nativeName)
                                .foregroundStyle(.primary)

                            if language.nativeName != language.englishName {
                                Text(verbatim: language.englishName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if appState.selectedLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.primary)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("App Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsLanguagePickerView()
        .environment(AppState.preview())
}
