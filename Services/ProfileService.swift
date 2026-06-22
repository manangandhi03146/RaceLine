import Foundation
import Supabase

/// Thin wrapper over the `profiles` table.
/// The row itself is created by an `on_auth_user_created` trigger in Supabase,
/// so we only need fetch + update here.
@MainActor
final class ProfileService {
    private let client = SupabaseManager.shared.client
    private let table  = "profiles"

    func fetchProfile(userID: UUID) async throws -> UserProfile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Supabase returns optional `email`; map snake_case to camelCase via CodingKeys.
        do {
            let response: UserProfile = try await client
                .from(table)
                .select()
                .eq("id", value: userID.uuidString)
                .single()
                .execute()
                .value
            return response
        } catch {
            // Row may not exist yet (trigger latency) — treat that as nil rather than throwing.
            if error.localizedDescription.lowercased().contains("row") ||
                error.localizedDescription.lowercased().contains("not found") {
                return nil
            }
            throw error
        }
    }

    func updateProfile(userID: UUID, _ update: UserProfileUpdate) async throws -> UserProfile {
        let response: UserProfile = try await client
            .from(table)
            .update(update)
            .eq("id", value: userID.uuidString)
            .select()
            .single()
            .execute()
            .value
        return response
    }

    /// First-launch helper. If Apple gave us a fresh display name (only happens on the
    /// very first sign-in) we write it without clobbering an existing one.
    func applyFirstSignInIfNeeded(userID: UUID, displayName: String?) async throws -> UserProfile? {
        guard let displayName, !displayName.isEmpty else {
            return try await fetchProfile(userID: userID)
        }
        let existing = try await fetchProfile(userID: userID)
        if let existing, let current = existing.displayName, !current.isEmpty {
            return existing
        }
        return try await updateProfile(userID: userID, .init(displayName: displayName))
    }
}
