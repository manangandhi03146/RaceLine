import AuthenticationServices
import Foundation
import Combine
import CryptoKit
import Supabase

/// Owns the authentication lifecycle for the app.
///
/// - Uses **Sign in with Apple** exclusively (via Supabase's `signInWithIdToken`).
/// - Drives a single `AuthState` machine that the root view subscribes to.
/// - Persists onboarding completion in `UserDefaults` keyed by Supabase user ID,
///   so a returning device knows to skip the onboarding screen.
@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var state: AuthState = .loading
    /// Last user-facing error from a failed sign-in attempt. Cleared on the next attempt.
    @Published var lastError: String?

    // MARK: - Convenience accessors used elsewhere in the app

    var isLoggedIn: Bool      { state.isAuthenticated }
    var userID: UUID?         { state.profile?.id }
    var userEmail: String?    { state.profile?.email }

    private let client          = SupabaseManager.shared.client
    private let profileService  = ProfileService()
    private let oauthLauncher    = OAuthLauncher()

    /// Nonce used for the most recent `SignInWithAppleButton` request.
    /// The button's own flow drives the credential UI; we provide the nonce
    /// when configuring the request and reuse the raw value here to verify
    /// the identity token with Supabase.
    private var pendingAppleNonce: String?

    /// URL scheme registered in Info.plist; Supabase will redirect here after OAuth completes.
    /// Must also be allow-listed in Supabase Dashboard → Authentication → URL Configuration.
    private let oauthRedirectURL = URL(string: "tread://login-callback")!
    private let oauthCallbackScheme = "tread"

    // MARK: - Lifecycle

    func initialize() async {
        state = .loading
        // Restore the persisted Supabase session if one exists.
        if let user = client.auth.currentUser {
            await refreshState(for: user, freshDisplayName: nil)
        } else {
            state = .signedOut
        }

        // Keep state in sync with future auth changes (token refresh, sign-out from another
        // place, etc.). We only need to react to signed-in / signed-out transitions here —
        // refresh events leave currentUser intact.
        Task { [weak self] in
            guard let self else { return }
            for await (event, session) in self.client.auth.authStateChanges {
                switch event {
                case .signedIn, .userUpdated, .tokenRefreshed:
                    if let user = session?.user {
                        await self.refreshState(for: user, freshDisplayName: nil)
                    }
                case .signedOut, .userDeleted:
                    self.state = .signedOut
                default:
                    break
                }
            }
        }
    }

    // MARK: - Sign in with Apple

    /// Hand to `SignInWithAppleButton`'s request-configuration closure.
    /// Generates a fresh nonce, stores the raw value for later verification,
    /// and asks Apple for the SHA-256 hash in the request.
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        pendingAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Hand to `SignInWithAppleButton`'s completion closure. Exchanges the
    /// Apple identity token with Supabase using the nonce we stashed during
    /// `configureAppleRequest`.
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        lastError = nil
        switch result {
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                // User dismissed Apple's sheet — quiet return.
                state = .signedOut
            } else {
                lastError = Self.friendlyMessage(for: error)
                state = .signedOut
            }
            pendingAppleNonce = nil

        case .success(let authorization):
            state = .authenticating
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = pendingAppleNonce else {
                lastError = "Apple didn't return a usable identity token. Please try again."
                state = .signedOut
                pendingAppleNonce = nil
                return
            }
            pendingAppleNonce = nil
            do {
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )
                let displayName = Self.combinedName(from: credential.fullName)
                await refreshState(for: session.user, freshDisplayName: displayName)
            } catch {
                lastError = Self.friendlyMessage(for: error)
                state = .signedOut
            }
        }
    }

    // MARK: - Sign in with Google (OAuth web flow)

    /// Opens the Supabase-hosted Google OAuth page in `ASWebAuthenticationSession`,
    /// waits for the redirect back into the app, and lets Supabase finalize the session.
    func signInWithGoogle() async {
        lastError = nil
        state = .authenticating
        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: oauthRedirectURL,
                scopes: nil,
                queryParams: []
            ) { [oauthLauncher, oauthCallbackScheme] url in
                try await oauthLauncher.launch(url: url, callbackURLScheme: oauthCallbackScheme)
            }
            await refreshState(for: session.user, freshDisplayName: nil)
        } catch OAuthLauncher.LauncherError.cancelled {
            state = .signedOut
        } catch {
            lastError = Self.friendlyMessage(for: error)
            state = .signedOut
        }
    }

    // MARK: - Onboarding

    /// Persists onboarding choices and transitions to `.signedIn`.
    func completeOnboarding(displayName: String, preferredUnits: String) async {
        guard case .needsOnboarding(let profile) = state else { return }
        state = .authenticating
        do {
            let updated = try await profileService.updateProfile(
                userID: profile.id,
                .init(displayName: displayName, preferredUnits: preferredUnits)
            )
            // Mirror the units choice into the existing AppStorage key so the rest of the
            // app picks it up without any wiring changes.
            UserDefaults.standard.set(preferredUnits, forKey: "preferredUnits")
            markOnboardingComplete(userID: profile.id)
            state = .signedIn(updated)
        } catch {
            // Even if the network update fails, don't trap the user in onboarding —
            // persist locally and let them in. We can retry the upload later.
            UserDefaults.standard.set(preferredUnits, forKey: "preferredUnits")
            markOnboardingComplete(userID: profile.id)
            var local = profile
            local.displayName = displayName
            local.preferredUnits = preferredUnits
            state = .signedIn(local)
        }
    }

    // MARK: - Sign out / delete

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Best-effort: even if Supabase rejects the request, clear local state.
        }
        state = .signedOut
    }

    func deleteAccount() async throws {
        guard let userID = state.profile?.id else { throw AuthError.notLoggedIn }
        let _: EmptyResponse = try await client.functions
            .invoke("delete-account", options: FunctionInvokeOptions(
                headers: ["Content-Type": "application/json"]
            ))
        clearOnboardingFlag(userID: userID)
        state = .signedOut
    }

    // MARK: - Helpers

    private func refreshState(for user: User, freshDisplayName: String?) async {
        do {
            // Pull the profile row (created by the on_auth_user_created trigger).
            // If Apple gave us a fresh display name on first sign-in, write it.
            let profile = try await profileService.applyFirstSignInIfNeeded(
                userID: user.id,
                displayName: freshDisplayName
            ) ?? UserProfile(
                id: user.id,
                email: user.email,
                displayName: freshDisplayName,
                preferredUnits: UserDefaults.standard.string(forKey: "preferredUnits") ?? "imperial",
                onboardingCompletedAt: nil
            )

            if hasCompletedOnboarding(userID: user.id) {
                state = .signedIn(profile)
            } else {
                state = .needsOnboarding(profile)
            }
        } catch {
            // Couldn't reach the profile row — gracefully fall back to a local
            // placeholder so the user can still proceed through onboarding.
            let fallback = UserProfile(
                id: user.id,
                email: user.email,
                displayName: freshDisplayName,
                preferredUnits: UserDefaults.standard.string(forKey: "preferredUnits") ?? "imperial",
                onboardingCompletedAt: nil
            )
            state = hasCompletedOnboarding(userID: user.id)
                ? .signedIn(fallback)
                : .needsOnboarding(fallback)
        }
    }

    private func hasCompletedOnboarding(userID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: Self.onboardingKey(userID: userID))
    }

    private func markOnboardingComplete(userID: UUID) {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey(userID: userID))
    }

    private func clearOnboardingFlag(userID: UUID) {
        UserDefaults.standard.removeObject(forKey: Self.onboardingKey(userID: userID))
    }

    private static func onboardingKey(userID: UUID) -> String {
        "onboardingComplete.\(userID.uuidString)"
    }

    // MARK: - Nonce helpers (shared with SignInWithAppleButton)

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private static func combinedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let name = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func friendlyMessage(for error: Error) -> String {
        let raw = error.localizedDescription
        let msg = raw.lowercased()
        if msg.contains("network") || msg.contains("offline") || msg.contains("connection") {
            return "Network error. Check your connection and try again."
        }
        if msg.contains("rate") || msg.contains("too many") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if msg.contains("token") || msg.contains("nonce") {
            return "Apple sign-in failed. Please try again."
        }
        return raw
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case notLoggedIn
        var errorDescription: String? { "You must be signed in to do this." }
    }
}

private struct EmptyResponse: Decodable {}
