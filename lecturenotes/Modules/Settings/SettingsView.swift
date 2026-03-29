import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var viewModel: SettingsViewModel
    @State private var supportEmailDraft: SupportEmailDraft?
    @State private var alertMessage = ""
    @State private var isAlertPresented = false
    @State private var isLanguagePickerPresented = false
    let analyticsService: AppAnalyticsService?

    init(
        authService: FirebaseAuthService? = nil,
        userProfileService: FirebaseUserProfileService? = nil,
        analyticsService: AppAnalyticsService? = nil
    ) {
        self.analyticsService = analyticsService
        _viewModel = State(
            initialValue: SettingsViewModel(
                authService: authService,
                userProfileService: userProfileService,
                analyticsService: analyticsService
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader(title: "Actions")

                SettingsActionRow(
                    title: .localized("Rate the app"),
                    systemImage: "star.bubble"
                ) {
                    requestReview()
                }

                SettingsRowDivider()

                SettingsActionRow(
                    title: viewModel.isRestoringPurchases ? .localized("Restoring purchases...") : .localized("Restore purchases"),
                    systemImage: "arrow.clockwise",
                    isDisabled: viewModel.isRestoringPurchases
                ) {
                    Task {
                        let message = await viewModel.restorePurchases(using: subscriptionManager)
                        presentAlert(message)
                    }
                }

                SettingsRowDivider()

                SettingsActionRow(
                    title: .localized("Contact support"),
                    systemImage: "envelope"
                ) {
                    let draft = viewModel.makeSupportEmailDraft()
                    analyticsService?.track(.supportEmailOpened)

                    if SettingsMailComposer.canSendMail {
                        supportEmailDraft = draft
                        return
                    }

                    openURL(draft.mailtoURL) { accepted in
                        if !accepted {
                            presentAlert(String(localized: "Unable to open Mail right now."))
                        }
                    }
                }

                SettingsSectionHeader(title: "Legal")

                SettingsActionRow(
                    title: .localized("Privacy Policy"),
                    systemImage: "lock.doc"
                ) {
                    openExternalURL(SettingsSupportConfiguration.privacyPolicyURL)
                }

                SettingsRowDivider()

                SettingsActionRow(
                    title: .localized("Terms of Use"),
                    systemImage: "doc.text"
                ) {
                    openExternalURL(SettingsSupportConfiguration.termsOfUseURL)
                }

                SettingsSectionHeader(title: "Language")

                SettingsNavigationRow(
                    title: "App Language",
                    value: appState.selectedLanguage.nativeName,
                    systemImage: "globe"
                ) {
                    isLanguagePickerPresented = true
                }

                SettingsSectionHeader(title: "Account")

                SettingsUserIDRow(
                    userID: viewModel.maskedUserID,
                    canCopyUserID: viewModel.canCopyUserID
                ) {
                    guard viewModel.copyUserID() else {
                        presentAlert(String(localized: "User ID is not available yet."))
                        return
                    }
                }

                SettingsRowDivider()

                SettingsStaticRow(
                    title: "App Version",
                    value: viewModel.appVersionText,
                    systemImage: "info.circle"
                )
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGray6))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            analyticsService?.track(.settingsOpened(plan: subscriptionManager.currentPlan))
        }
        .sheet(item: $supportEmailDraft) { draft in
            SettingsMailComposer(draft: draft)
        }
        .sheet(isPresented: $isLanguagePickerPresented) {
            SettingsLanguagePickerView(analyticsService: analyticsService)
        }
        .alert("Settings", isPresented: $isAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func openExternalURL(_ url: URL) {
        openURL(url) { accepted in
            if !accepted {
                presentAlert(String(localized: "Unable to open the link right now."))
            }
        }
    }

    private func presentAlert(_ message: String) {
        alertMessage = message
        isAlertPresented = true
    }
}

private struct SettingsSectionHeader: View {
    let title: LocalizedStringResource

    var body: some View {
        Text(title)
            .font(.title3)
            .bold()
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
    }
}

private enum SettingsRowTitle {
    case localized(LocalizedStringResource)
    case custom(String)
}

private struct SettingsRowTitleView: View {
    let title: SettingsRowTitle

    var body: some View {
        switch title {
        case .localized(let resource):
            Text(resource)
        case .custom(let string):
            Text(verbatim: string)
        }
    }
}

private struct SettingsActionRow: View {
    let title: SettingsRowTitle
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 12))

                SettingsRowTitleView(title: title)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

private struct SettingsUserIDRow: View {
    let userID: String
    let canCopyUserID: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.text.rectangle")
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.05))
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("User ID")
                    .bold()

                Text(userID)
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)

            Button("Copy user ID", systemImage: "doc.on.doc", action: onCopy)
                .labelStyle(.iconOnly)
                .foregroundStyle(canCopyUserID ? .primary : .secondary)
                .disabled(!canCopyUserID)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private struct SettingsNavigationRow: View {
    let title: LocalizedStringResource
    let value: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .bold()

                    Text(verbatim: value)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsStaticRow: View {
    let title: LocalizedStringResource
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.05))
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .bold()

                Text(value)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 76)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState.preview())
            .environmentObject(SubscriptionManager())
    }
}
