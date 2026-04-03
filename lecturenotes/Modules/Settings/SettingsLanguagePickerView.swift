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
            List {
                systemLanguageRow

                ForEach(AppLanguage.allCases) { language in
                    Button {
                        applyLanguageSelection(.specific(language))
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

                            if !appState.usesSystemLanguage && appState.selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
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

    private var systemLanguageRow: some View {
        Button {
            applyLanguageSelection(.system)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System")
                        .foregroundStyle(.primary)

                    Text(verbatim: appState.selectedLanguage.nativeName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if appState.usesSystemLanguage {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.primary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func applyLanguageSelection(_ selection: SettingsLanguageSelection) {
        let previousLanguage = appState.selectedLanguage

        switch selection {
        case .system:
            appState.useSystemLanguage()
        case .specific(let language):
            appState.setSelectedLanguage(language)
        }

        let newLanguage = appState.selectedLanguage
        if previousLanguage != newLanguage {
            analyticsService?.track(
                .languageChanged(
                    from: previousLanguage,
                    to: newLanguage
                )
            )
            crashReportingService?.breadcrumb(
                "language_changed",
                metadata: [
                    "from": previousLanguage.rawValue,
                    "to": newLanguage.rawValue,
                ]
            )
        }
        dismiss()
    }
}

private enum SettingsLanguageSelection {
    case system
    case specific(AppLanguage)
}

#Preview {
    SettingsLanguagePickerView()
        .environment(AppState.preview())
}
