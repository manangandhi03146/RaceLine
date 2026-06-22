import Foundation

/// Top-level authentication state. The root view switches on this — every other
/// auth-related flag (loading spinners, "needs onboarding", etc.) lives inside the case.
enum AuthState: Equatable {
    /// Still restoring the persisted session on launch.
    case loading
    /// No active Supabase session.
    case signedOut
    /// Apple credential is being exchanged with Supabase, or onboarding is being persisted.
    case authenticating
    /// Signed in but the user hasn't completed onboarding yet.
    case needsOnboarding(UserProfile)
    /// Signed in and fully set up.
    case signedIn(UserProfile)

    var profile: UserProfile? {
        switch self {
        case .needsOnboarding(let p), .signedIn(let p): return p
        default:                                        return nil
        }
    }

    var isAuthenticated: Bool {
        switch self {
        case .needsOnboarding, .signedIn: return true
        default:                          return false
        }
    }
}
