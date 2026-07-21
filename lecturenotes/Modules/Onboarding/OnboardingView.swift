import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState
    let analyticsService: AppAnalyticsService?
    let crashReportingService: CrashReportingService?
    @State private var selectedPageIndex = 0
    @State private var hasTrackedStart = false

    private var pages: [OnboardingPage] {
        OnboardingPage.defaultPages
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.canvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    OnboardingHeaderView(
                        showsSkip: selectedPageIndex < pages.count - 1,
                        onSkip: skipOnboarding
                    )

                    TabView(selection: $selectedPageIndex) {
                        ForEach(pages.indices, id: \.self) { index in
                            OnboardingPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .safeAreaInset(edge: .bottom) {
                OnboardingFooterView(
                    pageCount: pages.count,
                    selectedPageIndex: selectedPageIndex,
                    actionTitle: selectedPageIndex == pages.count - 1 ? "Get Started" : "Continue",
                    onPrimaryAction: handlePrimaryAction
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard !hasTrackedStart else {
                    return
                }

                hasTrackedStart = true
                crashReportingService?.setCurrentScreen("onboarding")
                crashReportingService?.setCurrentFlow("onboarding")
                crashReportingService?.breadcrumb("onboarding_started")
                analyticsService?.track(.onboardingStarted)
            }
        }
    }

    private func handlePrimaryAction() {
        if selectedPageIndex == pages.count - 1 {
            completeOnboarding()
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            selectedPageIndex += 1
        }
    }

    private func completeOnboarding() {
        crashReportingService?.breadcrumb("onboarding_completed")
        analyticsService?.track(
            .onboardingCompleted(
                pagesSeenCount: min(max(selectedPageIndex + 1, 1), pages.count)
            )
        )
        finishOnboarding()
    }

    private func finishOnboarding() {
        appState.needsOnboarding = false
    }

    private func skipOnboarding() {
        crashReportingService?.breadcrumb("onboarding_skipped", metadata: ["page_index": selectedPageIndex])
        analyticsService?.track(.onboardingSkipped(pageIndex: selectedPageIndex))
        finishOnboarding()
    }
}

private struct OnboardingHeaderView: View {
    let showsSkip: Bool
    let onSkip: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button("Skip", action: onSkip)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(showsSkip ? 1 : 0)
                .allowsHitTesting(showsSkip)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 12)

                OnboardingHeroView(
                    emoji: page.emoji
                )

                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(page.message)
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                OnboardingBenefitsCard(benefits: page.benefits)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 0)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct OnboardingHeroView: View {
    let emoji: String

    var body: some View {
        Text(emoji)
            .font(.system(size: 72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        .accessibilityHidden(true)
    }
}

private struct OnboardingBenefitsCard: View {
    let benefits: [LocalizedStringResource]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(benefits.indices, id: \.self) { index in
                OnboardingBenefitRow(title: benefits[index])
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppColor.hairline, lineWidth: 1)
        }
        .shadow(color: AppColor.shadow, radius: 10, y: 4)
    }
}

private struct OnboardingBenefitRow: View {
    let title: LocalizedStringResource

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColor.fillSubtle)
                    .frame(width: 28, height: 28)

                Image(systemName: "checkmark")
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
            .padding(.top, 2)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct OnboardingFooterView: View {
    let pageCount: Int
    let selectedPageIndex: Int
    let actionTitle: LocalizedStringResource
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            OnboardingPageIndicator(
                pageCount: pageCount,
                selectedPageIndex: selectedPageIndex
            )

            Button(action: onPrimaryAction) {
                ZStack {
                    Text("Get Started")
                        .font(.headline)
                        .opacity(0)

                    Text(actionTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .foregroundStyle(AppColor.onInk)
                .background(AppColor.ink)
                .clipShape(.rect(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(AppColor.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColor.fillSubtle)
                .frame(height: 1)
        }
    }
}

private struct OnboardingPageIndicator: View {
    let pageCount: Int
    let selectedPageIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPageIndex ? Color.primary : Color.primary.opacity(0.12))
                    .frame(width: index == selectedPageIndex ? 28 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: selectedPageIndex)
            }
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id: String
    let emoji: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let benefits: [LocalizedStringResource]

    static let defaultPages: [OnboardingPage] = [
        OnboardingPage(
            id: "capture",
            emoji: "🎙️",
            title: "Turn Any Lecture into Study Material",
            message: "Record audio or import text, PDF, and YouTube content to keep every lecture in one organized place.",
            benefits: [
                "Record or import in the format you already use",
                "Keep lectures, notes, and sources together",
                "Start studying without rebuilding your workflow"
            ]
        ),
        OnboardingPage(
            id: "summarize",
            emoji: "📝",
            title: "Get Clear Notes Without Replaying Everything",
            message: "LectraAI turns long material into a transcript plus concise summaries, so the main ideas are easy to review.",
            benefits: [
                "Short and detailed summaries for fast review",
                "Structured notes from dense lecture content",
                "Spend less time searching for the key points"
            ]
        ),
        OnboardingPage(
            id: "practice",
            emoji: "🎯",
            title: "Study with Flashcards and Quiz Practice",
            message: "Move from passive reading to active recall with built-in study modes generated from each lecture.",
            benefits: [
                "Flashcards for memorization and spaced review",
                "Quiz practice to check what you actually know",
                "One lecture becomes summary, recall, and practice"
            ]
        )
    ]
}

#Preview {
    OnboardingView(
        appState: AppState(),
        analyticsService: AppAnalyticsService(isEnabled: false),
        crashReportingService: CrashReportingService(isEnabled: false)
    )
}
