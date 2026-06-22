import AuthenticationServices
import Foundation
import UIKit

/// Drives an OAuth round-trip with `ASWebAuthenticationSession`.
/// Used by `AuthService` as the `launchFlow` closure for Supabase's `signInWithOAuth`.
@MainActor
final class OAuthLauncher: NSObject, ASWebAuthenticationPresentationContextProviding {

    enum LauncherError: LocalizedError {
        case cancelled
        case noCallbackURL
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .cancelled:           return "Sign-in cancelled."
            case .noCallbackURL:       return "Sign-in did not return a callback URL."
            case .underlying(let e):   return e.localizedDescription
            }
        }
    }

    /// Opens `url` in an in-app browser, waits for the redirect that starts with
    /// `callbackURLScheme`, and returns it. The Supabase SDK then parses it
    /// (extracting the access/refresh tokens) and finalizes the session.
    func launch(url: URL, callbackURLScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: LauncherError.cancelled)
                    return
                }
                if let error {
                    continuation.resume(throwing: LauncherError.underlying(error))
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: LauncherError.noCallbackURL)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            // `prefersEphemeralWebBrowserSession = true` would skip the iCloud Keychain
            // password autofill and any Safari cookies — leaving it false gives users a
            // smoother experience if they're already signed into Google in Safari.
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow }) ?? UIWindow()
        }
    }
}
