import Foundation
import Combine
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = true
    @Published private(set) var isEmailConfirmationPending = false

    private let client = SupabaseManager.shared.client

    var isLoggedIn: Bool { currentUser != nil }
    var userID: UUID? { currentUser?.id }
    var userEmail: String? { currentUser?.email }

    func initialize() async {
        isLoading = true
        currentUser = client.auth.currentUser
        isLoading = false

        Task {
            for await (event, session) in client.auth.authStateChanges {
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    currentUser = session?.user
                    isEmailConfirmationPending = false
                case .signedOut, .userDeleted:
                    currentUser = nil
                    isEmailConfirmationPending = false
                default:
                    break
                }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
        currentUser = client.auth.currentUser
    }

    enum SignUpOutcome {
        case signedIn
        case emailConfirmationRequired
    }

    @discardableResult
    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        let response = try await client.auth.signUp(email: email, password: password)
        let session = response.session
        let user = response.user
        if session != nil {
            currentUser = client.auth.currentUser ?? user
            isEmailConfirmationPending = false
            return .signedIn
        } else {
            currentUser = nil
            isEmailConfirmationPending = true
            return .emailConfirmationRequired
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "tread://auth/callback")
        )
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        guard let userID else { throw AuthError.notLoggedIn }

        // Call the Edge Function which handles full data + auth deletion
        let _: EmptyResponse = try await client.functions
            .invoke("delete-account", options: FunctionInvokeOptions(
                headers: ["Content-Type": "application/json"]
            ))

        // Clear local state
        currentUser = nil
        _ = userID  // suppress unused warning
    }

    enum AuthError: LocalizedError {
        case notLoggedIn
        var errorDescription: String? { "You must be signed in to do this." }
    }
}

private struct EmptyResponse: Decodable {}
