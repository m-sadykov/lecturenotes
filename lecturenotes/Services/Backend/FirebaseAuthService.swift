import FirebaseAuth
import Observation

@MainActor
@Observable
final class FirebaseAuthService {
    @ObservationIgnored private let auth: Auth

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    var currentUserID: String? {
        auth.currentUser?.uid
    }

    func ensureSignedIn() async throws -> User {
        if let currentUser = auth.currentUser {
            return currentUser
        }

        return try await withCheckedThrowingContinuation { continuation in
            auth.signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let user = result?.user else {
                    continuation.resume(throwing: FirebaseAuthServiceError.missingUser)
                    return
                }

                continuation.resume(returning: user)
            }
        }
    }
}

enum FirebaseAuthServiceError: LocalizedError {
    case missingUser

    var errorDescription: String? {
        switch self {
        case .missingUser:
            "Unable to sign in anonymously."
        }
    }
}
