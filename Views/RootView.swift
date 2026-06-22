import SwiftUI

/// Single source of truth for which screen the user sees on launch.
/// Switches purely on `authService.state` — no `localOnlyMode`, no parallel flags.
struct RootView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            switch authService.state {
            case .loading:
                LoadingView(message: "Starting up…")

            case .signedOut, .authenticating:
                AuthView()

            case .needsOnboarding(let profile):
                OnboardingView(profile: profile)

            case .signedIn:
                ContentView()
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: authService.state)
    }
}
