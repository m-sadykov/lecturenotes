import SwiftUI

struct SettingsLanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let analyticsService: AppAnalyticsService?
    let crashReportingService: CrashReportingService?

    init(
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil
    ) {
        self.analyticsService = analyticsService
        self.crashReportingService = crashReportingService
    }

    var body: some View {
        NavigationStack {
            List(AppLanguage.allCases) { language in
                Button {
                    let previousLanguage = appState.selectedLanguage
                    appState.selectedLanguage = language
                    if previousLanguage != language {
                        analyticsService?.track(
                            .languageChanged(
                                from: previousLanguage,
                                to: language
                            )
                        )
                        crashReportingService?.breadcrumb(
                            "language_changed",
                            metadata: [
                                "from": previousLanguage.rawValue,
                                "to": language.rawValue,
                            ]
                        )
                    }
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
