import SwiftUI

/// Top-level Social tab. Segmented hub for the four Phase 3 surfaces:
/// activity feed, groups, challenges, and riders (public profiles).
/// Uses the shared design system tokens so it feels native to RaceLine.
struct SocialHubView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var selection: SocialSegment = .feed

    enum SocialSegment: String, CaseIterable, Identifiable {
        case feed, groups, challenges, riders
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .feed:       return "Feed"
            case .groups:     return "Groups"
            case .challenges: return "Challenges"
            case .riders:     return "Riders"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                segmentBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                Group {
                    switch selection {
                    case .feed:       ActivityFeedTab()
                    case .groups:     GroupsTab()
                    case .challenges: ChallengesTab()
                    case .riders:     RidersTab()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .background(Color.appBg)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Social")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Color.appBg)
    }

    // MARK: - Segment bar

    private var segmentBar: some View {
        HStack(spacing: 6) {
            ForEach(SocialSegment.allCases) { seg in
                let isSelected = selection == seg
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = seg }
                } label: {
                    Text(seg.displayName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : Color.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(minHeight: 36)
                        .background(isSelected ? Color.appAccent : Color.appSurface2)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Activity feed tab

struct ActivityFeedTab: View {
    @EnvironmentObject private var authService: AuthService

    @State private var state: LoadState = .loading
    @State private var events: [ActivityEvent] = []
    @State private var profilesByID: [UUID: SocialProfile] = [:]

    private let feedService = ActivityFeedService()
    private let profileService = SocialProfileService()

    private enum LoadState: Equatable { case loading, loaded, empty, error(String) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                switch state {
                case .loading:
                    LoadingBlock(message: "Loading feed…")
                        .padding(.top, 40)
                case .empty:
                    EmptyStateView(
                        icon: "sparkles",
                        title: "Your feed is quiet",
                        message: "Follow other riders or join a group to start seeing activity here."
                    )
                    .padding(.top, 40)
                case .error(let message):
                    ErrorBlock(message: message) { Task { await reload() } }
                        .padding(.top, 40)
                case .loaded:
                    ForEach(events) { event in
                        feedRow(for: event)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .refreshable { await reload() }
        .task { await reload() }
    }

    // Wrap in a NavigationLink when the event kind has a tappable target.
    @ViewBuilder
    private func feedRow(for event: ActivityEvent) -> some View {
        let actor = profilesByID[event.actorID]
        switch event.kind {
        case .sharedRoutePosted:
            if let subjectID = event.subjectID {
                NavigationLink {
                    SharedRouteDetailView(routeID: subjectID)
                } label: {
                    FeedRow(event: event, actor: actor)
                }
                .buttonStyle(.plain)
            } else {
                FeedRow(event: event, actor: actor)
            }
        default:
            FeedRow(event: event, actor: actor)
        }
    }

    private func reload() async {
        guard authService.isLoggedIn else {
            state = .error("Sign in to see your feed.")
            return
        }
        state = .loading
        do {
            let list = try await feedService.feed(limit: 40)
            events = list
            state = list.isEmpty ? .empty : .loaded
            await loadActorProfiles(for: list)
        } catch {
            state = .error(userFacingSupabaseError(error, feature: "feed"))
        }
    }

    private func loadActorProfiles(for events: [ActivityEvent]) async {
        let ids = Set(events.map(\.actorID))
        let missing = ids.subtracting(profilesByID.keys)
        guard !missing.isEmpty else { return }
        if let fetched = try? await profileService.fetchProfiles(userIDs: Array(missing)) {
            for p in fetched { profilesByID[p.id] = p }
        }
    }
}

/// Turns raw Supabase / Postgrest errors into a message that helps diagnose
/// the common Phase 3 setup issue — migrations 006 + 007 not applied — while
/// still preserving the underlying error text so real issues aren't hidden.
func userFacingSupabaseError(_ error: Error, feature: String) -> String {
    let text = "\(error)"
    let lower = text.lowercased()
    if lower.contains("relation") && (lower.contains("does not exist") || lower.contains("not exist")) {
        return "The \(feature) tables aren't set up yet. Run supabase/migrations/006_social.sql and 007_social_rls.sql in the Supabase Dashboard, then pull to refresh."
    }
    if lower.contains("row level security") || lower.contains("permission denied") {
        return "Row-level security blocked that query. Confirm 007_social_rls.sql ran successfully."
    }
    if lower.contains("network") || lower.contains("offline") {
        return "You're offline. Reconnect and pull to refresh."
    }
    return "Couldn't load \(feature).\n\n\(text)"
}

private struct FeedRow: View {
    let event: ActivityEvent
    let actor: SocialProfile?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: event.kind.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(actorLine)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if event.kind == .sharedRoutePosted {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                if let title = event.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                }
                if let summary = event.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(event.createdAt, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textGhost)
            }
            Spacer(minLength: 0)
        }
        .minimalCard()
    }

    private var actorLine: String {
        if let actor {
            if let name = actor.displayName, !name.isEmpty { return name }
            if let u = actor.username, !u.isEmpty          { return "@\(u)" }
        }
        return "A rider"
    }
}

// MARK: - Groups tab (thin wrapper around GroupsView)

struct GroupsTab: View {
    var body: some View { GroupsView() }
}

// MARK: - Challenges tab

struct ChallengesTab: View {
    var body: some View { ChallengesView() }
}

// MARK: - Riders tab (search + follow)

struct RidersTab: View {
    @EnvironmentObject private var authService: AuthService

    @State private var query: String = ""
    @State private var results: [SocialProfile] = []
    @State private var searching = false
    @State private var errorMessage: String?
    @State private var followingIDs: Set<UUID> = []

    private let profileService = SocialProfileService()
    private let followService = FollowService()

    var body: some View {
        VStack(spacing: 12) {
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 10)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .padding()
                    }

                    if searching {
                        LoadingBlock(message: "Searching…")
                            .padding(.top, 20)
                    } else if !query.trimmingCharacters(in: .whitespaces).isEmpty && results.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No riders found",
                            message: "Only riders with a public profile show up in search."
                        )
                        .padding(.top, 20)
                    } else if results.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "Find fellow riders",
                            message: "Search by username or display name to follow other public riders."
                        )
                        .padding(.top, 20)
                    } else {
                        ForEach(results) { profile in
                            riderRow(profile)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 100)
            }
        }
        .task { await reloadFollowing() }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
            TextField("Search riders", text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { Task { await runSearch() } }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textGhost)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onChange(of: query) { _, _ in
            Task { await runSearch() }
        }
    }

    private func riderRow(_ profile: SocialProfile) -> some View {
        NavigationLink {
            PublicProfileView(userID: profile.id)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName ?? profile.username ?? "Rider")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if let username = profile.username {
                        Text("@\(username)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer()
                followButton(profile)
            }
            .minimalCard()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func followButton(_ profile: SocialProfile) -> some View {
        if profile.id == authService.userID {
            Text("You")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textGhost)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appSurface2)
                .clipShape(Capsule())
        } else {
            let following = followingIDs.contains(profile.id)
            Button {
                Task { await toggleFollow(profile) }
            } label: {
                Text(following ? "Following" : "Follow")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(following ? Color.appAccent : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(following ? Color.appAccent.opacity(0.15) : Color.appAccent)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            searching = false
            return
        }
        searching = true
        errorMessage = nil
        defer { searching = false }
        do {
            results = try await profileService.searchPublic(query: trimmed)
        } catch {
            errorMessage = userFacingSupabaseError(error, feature: "search")
            results = []
        }
    }

    private func toggleFollow(_ profile: SocialProfile) async {
        guard let me = authService.userID else { return }
        do {
            if followingIDs.contains(profile.id) {
                try await followService.unfollow(followerID: me, followeeID: profile.id)
                followingIDs.remove(profile.id)
            } else {
                try await followService.follow(followerID: me, followeeID: profile.id)
                followingIDs.insert(profile.id)
            }
        } catch {
            errorMessage = "Couldn't update follow. Try again."
        }
    }

    private func reloadFollowing() async {
        guard let me = authService.userID else { return }
        followingIDs = Set((try? await followService.following(userID: me)) ?? [])
    }
}

// MARK: - Shared UI

struct LoadingBlock: View {
    var message: String = "Loading…"
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Color.appAccent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct ErrorBlock: View {
    let message: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22))
                .foregroundStyle(Color.appAccent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Try again", action: retry)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
