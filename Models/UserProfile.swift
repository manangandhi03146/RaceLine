import Foundation

/// Mirror of the `profiles` row in Supabase. Only the columns we read or write are decoded.
struct UserProfile: Codable, Equatable {
    let id: UUID
    var email: String?
    var displayName: String?
    var preferredUnits: String
    var onboardingCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName            = "display_name"
        case preferredUnits         = "preferred_units"
        case onboardingCompletedAt  = "onboarding_completed_at"
    }
}

struct UserProfileUpdate: Encodable {
    var displayName: String?
    var preferredUnits: String?
    var onboardingCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case displayName           = "display_name"
        case preferredUnits        = "preferred_units"
        case onboardingCompletedAt = "onboarding_completed_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let v = displayName            { try c.encode(v, forKey: .displayName) }
        if let v = preferredUnits         { try c.encode(v, forKey: .preferredUnits) }
        if let v = onboardingCompletedAt  { try c.encode(v, forKey: .onboardingCompletedAt) }
    }
}
