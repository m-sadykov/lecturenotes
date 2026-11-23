import Foundation

/// Reported to Crashlytics as a non-fatal so stuck launches show up in the dashboard.
enum StartupDeadlineError: Error {
    /// Startup work was still running when the splash deadline passed.
    case splashTimedOut
}
