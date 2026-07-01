import Foundation
import Supabase

// MARK: - Table constants

private enum SocialTable {
    static let profiles         = "profiles"
    static let privacy          = "social_privacy_settings"
    static let follows          = "follows"
    static let groups           = "groups"
    static let groupMembers     = "group_members"
    static let groupRides       = "group_rides"
    static let challenges       = "challenges"
    static let challengeProgress = "challenge_progress"
    static let sharedRoutes     = "shared_routes"
    static let activityFeed     = "activity_feed"
}

// MARK: - Public profile

/// Read + write the social columns on `profiles`. Owner-editable, publicly
/// readable for users whose `is_public = TRUE` per RLS in migration 007.
struct SocialProfileService {
    private let client = SupabaseManager.shared.client

    func fetchProfile(userID: UUID) async throws -> SocialProfile? {
        do {
            let profile: SocialProfile = try await client
                .from(SocialTable.profiles)
                .select("id, username, display_name, bio, avatar_path, is_public, show_bikes, show_ride_stats")
                .eq("id", value: userID.uuidString)
                .single()
                .execute()
                .value
            return profile
        } catch {
            if isNotFound(error) { return nil }
            throw error
        }
    }

    func updateProfile(userID: UUID, _ update: SocialProfileUpdate) async throws -> SocialProfile {
        do {
            return try await client
                .from(SocialTable.profiles)
                .update(update)
                .eq("id", value: userID.uuidString)
                .select("id, username, display_name, bio, avatar_path, is_public, show_bikes, show_ride_stats")
                .single()
                .execute()
                .value
        } catch {
            if isUniqueViolation(error) { throw SocialError.duplicateUsername }
            throw error
        }
    }

    /// Fetch multiple profiles in a single request. RLS keeps this to
    /// (a) the caller's own profile and (b) profiles marked `is_public`.
    /// Returns whichever ones RLS lets through, in any order.
    func fetchProfiles(userIDs: [UUID]) async throws -> [SocialProfile] {
        guard !userIDs.isEmpty else { return [] }
        let ids = userIDs.map { $0.uuidString.lowercased() }
        return try await client
            .from(SocialTable.profiles)
            .select("id, username, display_name, bio, avatar_path, is_public, show_bikes, show_ride_stats")
            .in("id", values: ids)
            .execute()
            .value
    }

    /// Case-insensitive search by username/display_name for public profiles.
    /// Returns at most 20 rows.
    func searchPublic(query: String) async throws -> [SocialProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let pattern = "%\(trimmed)%"
        return try await client
            .from(SocialTable.profiles)
            .select("id, username, display_name, bio, avatar_path, is_public, show_bikes, show_ride_stats")
            .eq("is_public", value: true)
            .or("username.ilike.\(pattern),display_name.ilike.\(pattern)")
            .limit(20)
            .execute()
            .value
    }
}

// MARK: - Privacy settings

struct SocialPrivacyService {
    private let client = SupabaseManager.shared.client

    func fetch(userID: UUID) async throws -> SocialPrivacySettings {
        do {
            return try await client
                .from(SocialTable.privacy)
                .select()
                .eq("user_id", value: userID.uuidString)
                .single()
                .execute()
                .value
        } catch {
            if isNotFound(error) {
                // Row should always exist courtesy of the on_profile_created trigger;
                // if it doesn't, hand back safe defaults so the UI still renders.
                return .safeDefault(for: userID)
            }
            throw error
        }
    }

    func update(userID: UUID, _ update: SocialPrivacySettingsUpdate) async throws -> SocialPrivacySettings {
        try await client
            .from(SocialTable.privacy)
            .update(update)
            .eq("user_id", value: userID.uuidString)
            .select()
            .single()
            .execute()
            .value
    }
}

// MARK: - Follows

struct FollowService {
    private let client = SupabaseManager.shared.client

    private struct Row: Encodable {
        let follower_id: String
        let followee_id: String
    }

    func follow(followerID: UUID, followeeID: UUID) async throws {
        guard followerID != followeeID else { throw SocialError.validation("You can't follow yourself.") }
        try await client
            .from(SocialTable.follows)
            .upsert(Row(
                follower_id: followerID.uuidString.lowercased(),
                followee_id: followeeID.uuidString.lowercased()
            ), onConflict: "follower_id,followee_id")
            .execute()
    }

    func unfollow(followerID: UUID, followeeID: UUID) async throws {
        try await client
            .from(SocialTable.follows)
            .delete()
            .eq("follower_id", value: followerID.uuidString)
            .eq("followee_id", value: followeeID.uuidString)
            .execute()
    }

    /// Returns the followee ids that `userID` is following.
    func following(userID: UUID) async throws -> [UUID] {
        struct FolloweeRow: Decodable { let followee_id: UUID }
        let rows: [FolloweeRow] = try await client
            .from(SocialTable.follows)
            .select("followee_id")
            .eq("follower_id", value: userID.uuidString)
            .execute()
            .value
        return rows.map(\.followee_id)
    }

    func followers(userID: UUID) async throws -> [UUID] {
        struct FollowerRow: Decodable { let follower_id: UUID }
        let rows: [FollowerRow] = try await client
            .from(SocialTable.follows)
            .select("follower_id")
            .eq("followee_id", value: userID.uuidString)
            .execute()
            .value
        return rows.map(\.follower_id)
    }

    func isFollowing(follower: UUID, followee: UUID) async throws -> Bool {
        struct HitRow: Decodable {}
        do {
            let _: HitRow = try await client
                .from(SocialTable.follows)
                .select("follower_id")
                .eq("follower_id", value: follower.uuidString)
                .eq("followee_id", value: followee.uuidString)
                .single()
                .execute()
                .value
            return true
        } catch {
            if isNotFound(error) { return false }
            throw error
        }
    }
}

// MARK: - Groups

struct GroupService {
    private let client = SupabaseManager.shared.client

    // ----- Create / read -----

    /// Creates a group owned by the given user and returns the row. The DB
    /// trigger inserts the owner into `group_members` automatically.
    func createGroup(ownerID: UUID, name: String, description: String?, isPublic: Bool) async throws -> GroupSummary {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else { throw SocialError.validation("Group name is too short.") }
        let payload = GroupInsert(
            ownerID: ownerID,
            name: name,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            isPublic: isPublic,
            joinCode: Self.generateJoinCode()
        )
        return try await client
            .from(SocialTable.groups)
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Groups the user is currently a member of.
    func groups(forUser userID: UUID) async throws -> [GroupSummary] {
        struct JoinRow: Decodable {
            let group: GroupSummary
            enum CodingKeys: String, CodingKey { case group = "groups" }
        }
        let rows: [JoinRow] = try await client
            .from(SocialTable.groupMembers)
            .select("groups(*)")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        return rows.map(\.group).sorted { $0.createdAt > $1.createdAt }
    }

    func group(id: UUID) async throws -> GroupSummary {
        do {
            return try await client
                .from(SocialTable.groups)
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
        } catch {
            if isNotFound(error) { throw SocialError.notFound }
            throw error
        }
    }

    // ----- Join / leave -----

    private struct MemberInsert: Encodable {
        let group_id: String
        let user_id: String
        let role: String
    }

    func joinByCode(userID: UUID, code: String) async throws -> GroupSummary {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let group: GroupSummary
        do {
            group = try await client
                .from(SocialTable.groups)
                .select()
                .eq("join_code", value: trimmed)
                .single()
                .execute()
                .value
        } catch {
            if isNotFound(error) { throw SocialError.invalidJoinCode }
            throw error
        }
        try await join(userID: userID, groupID: group.id)
        return group
    }

    func join(userID: UUID, groupID: UUID) async throws {
        do {
            try await client
                .from(SocialTable.groupMembers)
                .insert(MemberInsert(
                    group_id: groupID.uuidString.lowercased(),
                    user_id: userID.uuidString.lowercased(),
                    role: GroupMemberRole.member.rawValue
                ))
                .execute()
        } catch {
            if isUniqueViolation(error) { throw SocialError.alreadyMember }
            throw error
        }
    }

    func leave(userID: UUID, groupID: UUID) async throws {
        try await client
            .from(SocialTable.groupMembers)
            .delete()
            .eq("group_id", value: groupID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
    }

    // ----- Members / rides -----

    func members(groupID: UUID) async throws -> [GroupMember] {
        try await client
            .from(SocialTable.groupMembers)
            .select()
            .eq("group_id", value: groupID.uuidString)
            .order("joined_at", ascending: true)
            .execute()
            .value
    }

    func groupRides(groupID: UUID, limit: Int = 25) async throws -> [GroupRide] {
        try await client
            .from(SocialTable.groupRides)
            .select()
            .eq("group_id", value: groupID.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    private struct GroupRideInsert: Encodable {
        let group_id: String
        let author_id: String
        let ride_id: String?
        let title: String
        let description: String?
        let scheduled_at: Date?
    }

    func postGroupRide(groupID: UUID,
                       authorID: UUID,
                       rideID: UUID?,
                       title: String,
                       description: String?,
                       scheduledAt: Date?) async throws -> GroupRide {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count >= 2 else { throw SocialError.validation("Title is too short.") }
        return try await client
            .from(SocialTable.groupRides)
            .insert(GroupRideInsert(
                group_id: groupID.uuidString.lowercased(),
                author_id: authorID.uuidString.lowercased(),
                ride_id: rideID?.uuidString.lowercased(),
                title: title,
                description: description?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                scheduled_at: scheduledAt
            ))
            .select()
            .single()
            .execute()
            .value
    }

    // ----- Utility -----

    /// 8-character A-Z/2-9 code. Excludes 0/O/1/I for legibility.
    static func generateJoinCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }
}

// MARK: - Challenges

struct ChallengeService {
    private let client = SupabaseManager.shared.client

    func activeChallenges() async throws -> [Challenge] {
        try await client
            .from(SocialTable.challenges)
            .select()
            .eq("is_active", value: true)
            .order("starts_at", ascending: false)
            .execute()
            .value
    }

    func challenge(id: UUID) async throws -> Challenge {
        do {
            return try await client
                .from(SocialTable.challenges)
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
        } catch {
            if isNotFound(error) { throw SocialError.notFound }
            throw error
        }
    }

    func groupChallenges(groupID: UUID) async throws -> [Challenge] {
        try await client
            .from(SocialTable.challenges)
            .select()
            .eq("group_id", value: groupID.uuidString)
            .order("starts_at", ascending: false)
            .execute()
            .value
    }

    func progress(userID: UUID) async throws -> [ChallengeProgress] {
        try await client
            .from(SocialTable.challengeProgress)
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
    }

    func progress(userID: UUID, challengeID: UUID) async throws -> ChallengeProgress? {
        do {
            return try await client
                .from(SocialTable.challengeProgress)
                .select()
                .eq("challenge_id", value: challengeID.uuidString)
                .eq("user_id", value: userID.uuidString)
                .single()
                .execute()
                .value
        } catch {
            if isNotFound(error) { return nil }
            throw error
        }
    }

    private struct ProgressUpsert: Encodable {
        let challenge_id: String
        let user_id: String
        let current_value: Double
        let completed_at: Date?
    }

    /// Join a challenge without changing progress. Idempotent.
    func joinChallenge(userID: UUID, challengeID: UUID) async throws -> ChallengeProgress {
        return try await client
            .from(SocialTable.challengeProgress)
            .upsert(ProgressUpsert(
                challenge_id: challengeID.uuidString.lowercased(),
                user_id: userID.uuidString.lowercased(),
                current_value: 0,
                completed_at: nil
            ), onConflict: "challenge_id,user_id")
            .select()
            .single()
            .execute()
            .value
    }

    /// Record progress. Marks completed_at when `currentValue >= goalValue`.
    func recordProgress(userID: UUID,
                        challenge: Challenge,
                        currentValue: Double) async throws -> ChallengeProgress {
        let completedAt: Date? = currentValue >= challenge.goalValue ? Date() : nil
        return try await client
            .from(SocialTable.challengeProgress)
            .upsert(ProgressUpsert(
                challenge_id: challenge.id.uuidString.lowercased(),
                user_id: userID.uuidString.lowercased(),
                current_value: currentValue,
                completed_at: completedAt
            ), onConflict: "challenge_id,user_id")
            .select()
            .single()
            .execute()
            .value
    }

    func leaveChallenge(userID: UUID, challengeID: UUID) async throws {
        try await client
            .from(SocialTable.challengeProgress)
            .delete()
            .eq("challenge_id", value: challengeID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
    }
}

// MARK: - Shared routes

struct SharedRouteService {
    private let client = SupabaseManager.shared.client

    /// Post a ride's route with the requested visibility. The caller is
    /// expected to have already applied any trim/hide adjustments.
    func post(_ insert: SharedRouteInsert) async throws -> SharedRoute {
        try await client
            .from(SocialTable.sharedRoutes)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    /// Routes the user has posted themselves.
    func routes(byAuthor userID: UUID, limit: Int = 50) async throws -> [SharedRoute] {
        try await client
            .from(SocialTable.sharedRoutes)
            .select()
            .eq("author_id", value: userID.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Single shared route by id. RLS enforces visibility — returns
    /// SocialError.notFound if the caller isn't allowed to view it.
    func route(id: UUID) async throws -> SharedRoute {
        do {
            return try await client
                .from(SocialTable.sharedRoutes)
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
        } catch {
            if isNotFound(error) { throw SocialError.notFound }
            throw error
        }
    }

    /// Publicly-visible routes (RLS filters everything else automatically).
    func publicRoutes(limit: Int = 50) async throws -> [SharedRoute] {
        try await client
            .from(SocialTable.sharedRoutes)
            .select()
            .eq("visibility", value: SharedRouteVisibility.publicVisible.rawValue)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func delete(routeID: UUID) async throws {
        try await client
            .from(SocialTable.sharedRoutes)
            .delete()
            .eq("id", value: routeID.uuidString)
            .execute()
    }

    // MARK: Sanitizer

    /// Apply the hide-start / hide-end / trim rules to a raw route before
    /// building the insert payload. Keeps sanitization in the app so we never
    /// upload private data by mistake.
    static func sanitize(points: [RidePoint],
                         hideStart: Bool,
                         hideEnd: Bool,
                         trim: Int) -> [SharedRoutePoint] {
        let base = points.map(SharedRoutePoint.init)
        guard !base.isEmpty else { return [] }
        let startTrim = hideStart ? max(0, trim) : 0
        let endTrim   = hideEnd   ? max(0, trim) : 0
        let clampedStart = min(startTrim, max(0, base.count - 1))
        let remaining = base.count - clampedStart
        let clampedEnd = min(endTrim, max(0, remaining - 1))
        let sliced = base.dropFirst(clampedStart).dropLast(clampedEnd)
        return Array(sliced)
    }
}

// MARK: - Activity feed

struct ActivityFeedService {
    private let client = SupabaseManager.shared.client

    /// Feed items the current user is allowed to see. RLS filters everything
    /// down to actor-own + follower/group/public rows.
    func feed(limit: Int = 40) async throws -> [ActivityEvent] {
        try await client
            .from(SocialTable.activityFeed)
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func emit(_ insert: ActivityEventInsert) async throws {
        try await client
            .from(SocialTable.activityFeed)
            .insert(insert)
            .execute()
    }

    /// Convenience: emit an event unless privacy switches are off. Silently
    /// returns without writing when the user has that activity kind muted.
    func emitIfAllowed(_ insert: ActivityEventInsert,
                       privacy: SocialPrivacySettings) async throws {
        switch insert.kind {
        case .rideCompleted:
            guard privacy.showRideActivities else { return }
        case .challengeJoined, .challengeCompleted:
            guard privacy.showChallengeActivities else { return }
        case .maintenanceLogged:
            guard privacy.showMaintenanceActivities else { return }
        case .groupRideCreated, .joinedGroup:
            guard privacy.showGroupActivities else { return }
        case .sharedRoutePosted:
            // Always emit — the visibility of the underlying route already
            // gates the reach; the activity row uses the same visibility.
            break
        }
        try await emit(insert)
    }
}

// MARK: - Error helpers

private func isNotFound(_ error: Error) -> Bool {
    let text = "\(error)".lowercased()
    return text.contains("not found")
        || text.contains("no rows")
        || text.contains("no rows returned")
        || text.contains("pgrst116")
}

private func isUniqueViolation(_ error: Error) -> Bool {
    let text = "\(error)".lowercased()
    return text.contains("duplicate key")
        || text.contains("unique constraint")
        || text.contains("23505")
}

// MARK: - Small helpers

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
