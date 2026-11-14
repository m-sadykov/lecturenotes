import Foundation
import Observation

/// "New set" state shared by the flashcards and quiz screens: whether the action is
/// offered, the request in flight, and the error to show.
@MainActor
@Observable
final class StudyItemsRegenerationModel<Item: Sendable> {
    enum Access: Equatable {
        /// No backend or the lecture isn't processed yet: the button is hidden.
        case unavailable
        /// The plan doesn't include regeneration: the button opens the paywall.
        case upgradeRequired
        case available
    }

    let access: Access
    private(set) var isRegenerating = false
    var error: StudyItemsRegenerationError?

    @ObservationIgnored private let regenerate: () async throws -> [Item]
    @ObservationIgnored private let onUpgradeRequested: () -> Void

    init(
        access: Access,
        regenerate: @escaping () async throws -> [Item],
        onUpgradeRequested: @escaping () -> Void
    ) {
        self.access = access
        self.regenerate = regenerate
        self.onUpgradeRequested = onUpgradeRequested
    }

    /// A model that never offers the action, for previews and screens without a backend.
    static var unavailable: StudyItemsRegenerationModel<Item> {
        StudyItemsRegenerationModel(access: .unavailable, regenerate: { [] }, onUpgradeRequested: {})
    }

    var isOffered: Bool {
        access != .unavailable
    }

    var isErrorPresented: Bool {
        get { error != nil }
        set {
            if !newValue {
                error = nil
            }
        }
    }

    /// Whether tapping the button should go straight to the paywall instead of asking
    /// to replace the current set.
    var requiresUpgrade: Bool {
        access == .upgradeRequired
    }

    /// Set by the "New Set" button; the screen asks before replacing the current set.
    var isConfirmationPresented = false

    func requestUpgrade() {
        onUpgradeRequested()
    }

    /// The "New Set" button's action: the paywall for plans without the feature,
    /// otherwise a confirmation before the current set is replaced.
    func requestNewSet() {
        if requiresUpgrade {
            requestUpgrade()
        } else if access == .available {
            isConfirmationPresented = true
        }
    }

    /// Fetches a new set. Returns it, or `nil` after storing the error to show; a plan
    /// error from the backend opens the paywall instead.
    func generate() async -> [Item]? {
        guard access == .available, !isRegenerating else {
            return nil
        }

        isRegenerating = true
        defer { isRegenerating = false }

        do {
            return try await regenerate()
        } catch let regenerationError as StudyItemsRegenerationError {
            if regenerationError == .planRequired {
                onUpgradeRequested()
            } else {
                error = regenerationError
            }
            return nil
        } catch {
            self.error = .failed
            return nil
        }
    }
}
