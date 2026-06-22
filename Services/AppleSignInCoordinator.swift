import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Result of a successful Apple credential request, ready to hand to Supabase.
struct AppleSignInResult {
    let idToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
    let email: String?
    let userIdentifier: String
}

/// Wraps `ASAuthorizationController` behind an async/await API.
/// - Generates a fresh cryptographically-random nonce per request.
/// - Hashes it (SHA-256) for the Apple request; keeps the raw value so Supabase can verify it.
@MainActor
final class AppleSignInCoordinator: NSObject {

    enum CoordinatorError: LocalizedError {
        case missingIdentityToken
        case invalidCredentialType
        case cancelled
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .missingIdentityToken:    return "Apple didn't return an identity token. Please try again."
            case .invalidCredentialType:   return "Unexpected Apple credential type."
            case .cancelled:               return "Sign-in cancelled."
            case .underlying(let error):   return error.localizedDescription
            }
        }
    }

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?

    func requestSignIn() async throws -> AppleSignInResult {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request  = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            controller.performRequests()
        }
    }

    // MARK: - Nonce helpers

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
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            defer { continuation = nil }

            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                continuation?.resume(throwing: CoordinatorError.invalidCredentialType)
                return
            }
            guard let nonce = currentNonce else {
                continuation?.resume(throwing: CoordinatorError.missingIdentityToken)
                return
            }
            guard let tokenData = appleCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                continuation?.resume(throwing: CoordinatorError.missingIdentityToken)
                return
            }

            let result = AppleSignInResult(
                idToken: idToken,
                rawNonce: nonce,
                fullName: appleCredential.fullName,
                email: appleCredential.email,
                userIdentifier: appleCredential.user
            )
            currentNonce = nil
            continuation?.resume(returning: result)
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        Task { @MainActor in
            defer { continuation = nil }
            currentNonce = nil
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                continuation?.resume(throwing: CoordinatorError.cancelled)
            } else {
                continuation?.resume(throwing: CoordinatorError.underlying(error))
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Find the active key window. Falls back to a fresh window if needed
        // (Apple's sign-in sheet wants a non-nil anchor).
        let anchor = MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow }) ?? UIWindow()
        }
        return anchor
    }
}
