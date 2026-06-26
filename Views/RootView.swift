import SwiftUI

/// Single source of truth for which screen the user sees on launch.
/// First-launch intro takes precedence; after that, the auth state machine drives routing.
struct RootView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("hasSeenIntroTutorial") private var hasSeenIntroTutorial: Bool = false

    var body: some View {
        Group {
            if !hasSeenIntroTutorial {
                IntroTutorialView {
                    // Flag is set inside the view itself before this fires; the
                    // @AppStorage binding will pick it up and re-render.
                    hasSeenIntroTutorial = true
                }
            } else {
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
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: authService.state)
        .animation(.easeInOut(duration: 0.25), value: hasSeenIntroTutorial)
    }
}
