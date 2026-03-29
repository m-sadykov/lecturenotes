import SwiftUI

struct HomeHeaderView: View {
    let authService: FirebaseAuthService?
    let userProfileService: FirebaseUserProfileService?
    let analyticsService: AppAnalyticsService?
    let crashReportingService: CrashReportingService?

    var body: some View {
        HStack {
            Text("LectraAI")
                .font(.title)
                .bold()
            Spacer()
            NavigationLink {
                SettingsView(
                    authService: authService,
                    userProfileService: userProfileService,
                    analyticsService: analyticsService,
                    crashReportingService: crashReportingService
                )
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.05))
                    .clipShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }
}
