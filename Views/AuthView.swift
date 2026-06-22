import AuthenticationServices
import SwiftUI

/// Sign-in screen. Apple ID is the only supported method.
struct AuthView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                // Hero
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                            .frame(width: 104, height: 104)
                        Image(systemName: "motorcycle")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }

                    VStack(spacing: 6) {
                        Text("Tread")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        Text("Privacy-first ride tracking.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer(minLength: 32)

                // Auth card
                VStack(spacing: 18) {
                    VStack(spacing: 4) {
                        Text("Sign in to continue")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                        Text("Use your Apple ID. We never see your password and never email-spam you.")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if authService.state == .authenticating {
                        ProgressView()
                            .tint(Color.appAccent)
                            .scaleEffect(1.1)
                            .frame(height: 108)
                    } else {
                        VStack(spacing: 10) {
                            SignInWithAppleButton(.continue) { request in
                                // The button itself is just for visuals/accessibility;
                                // `AppleSignInCoordinator` runs the real request.
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { _ in
                                Task { await authService.signInWithApple() }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel("Continue with Apple")

                            googleSignInButton
                        }
                    }

                    if let error = authService.lastError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .minimalCard()
                .padding(.horizontal, 20)

                Spacer()

                // Legal footer
                Text("By continuing you agree to our terms and privacy policy.")
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Google button

    private var googleSignInButton: some View {
        Button {
            Task { await authService.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                GoogleGlyph()
                    .frame(width: 18, height: 18)
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with Google")
    }
}

/// A simple multi-colored "G" rendered with overlapping shapes so we don't need to
/// ship Google's brand asset. Close enough for a clean primary-action button.
private struct GoogleGlyph: View {
    var body: some View {
        Image(systemName: "g.circle.fill")
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.white, Color(red: 0.26, green: 0.52, blue: 0.96)) // glyph, bg
            .overlay(
                Image(systemName: "g.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
            )
    }
}
