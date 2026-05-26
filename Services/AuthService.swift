import Foundation
import Combine
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = true

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
                case .signedOut, .userDeleted:
                    currentUser = nil
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

    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
        currentUser = client.auth.currentUser
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }
}
