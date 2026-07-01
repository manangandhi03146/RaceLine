import SwiftUI

/// Active challenges list with per-user progress. Safe challenge types only —
/// no top-speed leaderboards or public-road speed contests.
struct ChallengesView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var challenges: [Challenge] = []
    @State private var progressByID: [UUID: ChallengeProgress] = [:]
    @State private var state: LoadState = .loading

    private let service = ChallengeService()

    private enum LoadState: Equatable { case loading, loaded, empty, error(String) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                switch state {
                case .loading:
                    LoadingBlock(message: "Loading challenges…")
                        .padding(.top, 40)
                case .empty:
                    EmptyStateView(
                        icon: "target",
                        title: "No active challenges",
                        message: "Check back soon — new challenges roll out with each season."
                    )
                    .padding(.top, 40)
                case .error(let m):
                    ErrorBlock(message: m) { Task { await reload() } }
                        .padding(.top, 20)
                case .loaded:
                    ForEach(challenges) { challenge in
                        NavigationLink {
                            ChallengeDetailView(challenge: challenge)
                        } label: {
                            ChallengeRow(
                                challenge: challenge,
                                progress: progressByID[challenge.id]
                            )
                        }
                        .buttonStyle(.plain)
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

    private func reload() async {
        state = .loading
        do {
            let list = try await service.activeChallenges()
            var progresses: [ChallengeProgress] = []
            if let uid = authService.userID {
                progresses = (try? await service.progress(userID: uid)) ?? []
            }
            challenges = list
            progressByID = Dictionary(uniqueKeysWithValues: progresses.map { ($0.challengeID, $0) })
            state = list.isEmpty ? .empty : .loaded
        } catch {
            state = .error("Couldn't load challenges.")
        }
    }
}

// MARK: - Row

private struct ChallengeRow: View {
    let challenge: Challenge
    let progress: ChallengeProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: challenge.challengeType.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(challenge.challengeType.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                if progress?.completedAt != nil {
                    Text("Complete")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.9))
                        .clipShape(Capsule())
                } else if progress != nil {
                    Text("Joined")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appAccent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            ProgressBar(fraction: fraction)
            Text(progressCopy)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .minimalCard()
    }

    private var fraction: Double {
        guard let p = progress, challenge.goalValue > 0 else { return 0 }
        return min(1.0, p.currentValue / challenge.goalValue)
    }

    private var progressCopy: String {
        let current = progress?.currentValue ?? 0
        return String(format: "%.0f / %.0f %@",
                      current,
                      challenge.goalValue,
                      challenge.goalUnit)
    }
}

private struct ProgressBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.appSurface2)
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: max(4, geo.size.width * CGFloat(fraction)))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Detail

struct ChallengeDetailView: View {
    let challenge: Challenge

    @EnvironmentObject private var authService: AuthService

    @State private var progress: ChallengeProgress?
    @State private var errorMessage: String?
    @State private var joining = false

    private let service = ChallengeService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                if let progress {
                    progressCard(progress)
                }
                joinButton
                safetyNote
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(Color.appBg.ignoresSafeArea())
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appSurface, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadProgress() }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: challenge.challengeType.systemImage)
                    .foregroundStyle(Color.appAccent)
                Text(challenge.challengeType.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            Text(challenge.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            if let d = challenge.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Goal: \(Int(challenge.goalValue)) \(challenge.goalUnit)")
                .font(.caption)
                .foregroundStyle(Color.textGhost)
        }
        .minimalCard()
    }

    private func progressCard(_ p: ChallengeProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR PROGRESS")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(Color.textGhost)
            HStack {
                Text("\(Int(p.currentValue)) / \(Int(challenge.goalValue))")
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if p.completedAt != nil {
                    Text("Completed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.9))
                        .clipShape(Capsule())
                }
            }
            ProgressBar(fraction: min(1.0, p.currentValue / max(challenge.goalValue, 1)))
        }
        .minimalCard()
    }

    private var joinButton: some View {
        Button {
            Task { await join() }
        } label: {
            Text(progress == nil ? "Join Challenge" : "Update Progress")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(joining)
    }

    private var safetyNote: some View {
        Text("Challenges track riding habits and consistency. They don't reward speeding or risk-taking — always ride within your limits and the law.")
            .font(.caption)
            .foregroundStyle(Color.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func loadProgress() async {
        guard let uid = authService.userID else { return }
        progress = try? await service.progress(userID: uid, challengeID: challenge.id)
    }

    private func join() async {
        guard let uid = authService.userID else { errorMessage = "Sign in to join."; return }
        joining = true
        defer { joining = false }
        do {
            let updated = try await service.joinChallenge(userID: uid, challengeID: challenge.id)
            progress = updated
            _ = try? await ActivityFeedService().emit(ActivityEventInsert(
                actorID: uid,
                kind: .challengeJoined,
                subjectID: challenge.id,
                subjectKind: "challenge",
                title: "Joined a challenge",
                summary: challenge.title,
                visibility: .followers,
                groupID: challenge.groupID
            ))
        } catch {
            errorMessage = "Couldn't join right now."
        }
    }
}
